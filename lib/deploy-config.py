#!/usr/bin/env python3
"""Overlay durable payloads without following destination directory symlinks."""

import os
import shutil
import stat
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
TEMPLATED = {
    '.config/niri/envs.kdl', '.config/niri/dms/binds.kdl',
    '.config/herdr/plugins/local/eco-ws-number/herdr-plugin.toml',
}


def checked_parent(root, target):
    for parent in [*reversed(target.parent.parents), target.parent]:
        if parent == root or not parent.is_relative_to(root):
            continue
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise RuntimeError(f'Refusing unsafe destination directory: {parent}')
    target.parent.mkdir(parents=True, exist_ok=True)


def deploy():
    home = Path(os.environ['REAL_HOME']).resolve(strict=True)
    if Path(os.environ['USER_CONFIG']) != Path(os.environ['REAL_HOME']) / '.config':
        raise RuntimeError('This personal profile expects ~/.config')
    mode = os.environ.get('ECO_CONFIG_MODE', 'replace')
    profile = os.environ.get('ECO_PROFILE', 'portable')
    if mode not in {'preserve', 'replace'} or profile not in {'portable', 'ernesto'}:
        raise RuntimeError('Invalid configuration mode/profile')
    sources = {}
    for variable, destination in [
        ('INSTALLER_XDG_CONFIG_DIR', '.config'), ('INSTALLER_HOME_ROOT_CONFIG_DIR', '.'),
        ('INSTALLER_LOCAL_BIN_DIR', '.local/bin'), ('INSTALLER_LOCAL_SHARE_DIR', '.local/share'),
    ]:
        root = Path(os.environ[variable])
        for source in sorted(root.rglob('*')):
            if source.is_file() or source.is_symlink():
                sources[Path(destination) / source.relative_to(root)] = source
    if profile != 'portable':
        root = REPO / 'profiles' / profile / 'xdg-config'
        for source in sorted(root.rglob('*')):
            if source.is_file():
                sources[Path('.config') / source.relative_to(root)] = source
    # Check directory chains before replacing destination files, including backups.
    for relative in sources:
        checked_parent(home, home / relative)
    checked_parent(home, home / '.local/state/eco-linux/config-backups/placeholder')
    backup = None
    copied = preserved = 0
    for relative, source in sources.items():
        target = home / relative
        exists = os.path.lexists(target)
        if exists and mode == 'preserve':
            preserved += 1
            continue
        if exists and target.is_dir() and not target.is_symlink():
            raise RuntimeError(f'Refusing to replace directory with file: {target}')
        permissions = stat.S_IMODE(source.stat().st_mode)
        if str(relative) == '.config/opencode/cli.json':
            permissions = 0o600
        if str(relative).startswith('.config/yazi/plugins/'):
            permissions = 0o444
        content = None if source.is_symlink() else source.read_bytes()
        if str(relative) in TEMPLATED:
            content = content.replace(b'__HOME__', str(home).encode())
        if exists and not target.is_symlink() and content is not None and target.read_bytes() == content:
            target.chmod(permissions)
            continue
        if exists:
            if backup is None:
                backup = Path(tempfile.mkdtemp(prefix='replace-', dir=home / '.local/state/eco-linux/config-backups'))
            saved = backup / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, saved, follow_symlinks=False)
        # Atomic replacement never follows a destination file symlink.
        fd, temporary = tempfile.mkstemp(prefix='.eco-', dir=target.parent)
        os.close(fd)
        temporary = Path(temporary)
        try:
            if source.is_symlink():
                temporary.unlink()
                temporary.symlink_to(os.readlink(source))
            else:
                temporary.write_bytes(content)
                temporary.chmod(permissions)
            temporary.replace(target)
        finally:
            temporary.unlink(missing_ok=True)
        copied += 1
    print(f'Configuration: {copied} deployed, {preserved} existing files preserved; profile={profile}')
    if backup:
        print(f'Replaced files backed up to {backup}')


if __name__ == '__main__':
    deploy()
