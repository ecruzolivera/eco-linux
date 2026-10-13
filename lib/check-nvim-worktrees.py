#!/usr/bin/env python3
"""Refuse editor restoration when existing plugin checkouts contain user edits."""
import subprocess
from pathlib import Path


def check(root):
    if root.is_symlink():
        raise RuntimeError(f'Plugin directory is a symlink; review manually: {root}')
    if not root.exists():
        return
    for plugin in sorted(root.iterdir()):
        if plugin.is_symlink():
            raise RuntimeError(f'Linked plugin preserved for manual restoration: {plugin}')
        if not plugin.is_dir() or not (plugin / '.git').exists():
            continue
        dirty = subprocess.check_output(['git', '-C', str(plugin), 'status', '--porcelain', '--untracked-files=normal'], text=True)
        if dirty:
            raise RuntimeError(f'Plugin edits/untracked files preserved; review before restoration: {plugin.name}')


if __name__ == '__main__':
    check(Path.home() / '.local/share/nvim/lazy')
