#!/usr/bin/env python3
"""Read-only manifest, executable and installed-package coverage checks."""
import argparse
import os
import re
import shutil
import subprocess
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
BOOTSTRAP = {'base-devel', 'git', 'curl', 'python', 'sudo', 'yay'}
BASE = {'bash', 'coreutils', 'gawk', 'grep', 'sed'}


def manifest(name):
    entries = [line.split('#')[0].strip() for line in (REPO / 'packages' / name).read_text().splitlines()]
    entries = [entry for entry in entries if entry]
    assert all(re.fullmatch(r'[a-z0-9][a-z0-9+_.-]*', entry) for entry in entries), name
    assert len(entries) == len(set(entries)), f'Duplicate in {name}'
    return set(entries)


def selected(profile):
    result = BOOTSTRAP | manifest('core.official') | manifest('core.aur')
    if profile == 'personal':
        result |= manifest('personal.official') | manifest('personal.aur')
    for line in (REPO / 'packages/integrations.lock').read_text().splitlines():
        if not line or line.startswith('#'):
            continue
        name, revision, version = line.split()
        assert re.fullmatch('[0-9a-f]{40}', revision), name
        assert re.fullmatch(r'[0-9][A-Za-z0-9.+_-]*', version), name
        result.add(name)
    return result


def validate(profile):
    required = selected(profile)
    official = manifest('core.official') | manifest('personal.official')
    aur = manifest('core.aur') | manifest('personal.aur')
    assert not official & aur, 'Package declared in both Arch and AUR'
    assert not manifest('core.official') & manifest('personal.official'), 'Duplicated profile package'
    assert not manifest('core.aur') & manifest('personal.aur'), 'Duplicated AUR profile package'
    commands = tomllib.loads((REPO / 'packages/commands.toml').read_text())
    runtimes = tomllib.loads((REPO / 'xdg-config/mise/config.toml').read_text())['tools']
    full = selected('personal') | BASE
    for name, package in {**commands['commands'], **commands['personal_commands']}.items():
        if package == '@payload':
            assert os.access(REPO / 'local-bin' / name, os.X_OK), f'Missing executable helper: {name}'
        elif package.startswith('mise:'):
            assert package[5:] in runtimes, f'Missing runtime declaration: {name}'
        else:
            assert package in full, f'Undeclared provider of {name}: {package}'
    # All direct/sh startup and binding launch commands must be represented.
    known = commands['commands'] | commands['personal_commands']
    for path in (REPO / 'xdg-config/niri').rglob('*.kdl'):
        for command in re.findall(r'\bspawn(?:-sh)?(?:-at-startup)?\s+"([^"\n]+)"', path.read_text()):
            first = command.split()[0]
            if first == '$TERMINAL':
                first = 'kitty'
            first = first.rsplit('/', 1)[-1]
            assert first in known, f'Unaccounted Niri executable: {first} in {path.name}'
    return required, commands


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['core', 'personal'], default='personal')
    parser.add_argument('--installed', action='store_true', help='Classify installed explicit packages without changing anything')
    parser.add_argument('--commands', action='store_true', help='Require selected commands in the current user PATH')
    parser.add_argument('--packages', action='store_true', help='Require selected packages/providers to be installed')
    parser.add_argument('--check-repos', action='store_true', help='Check cached official databases, ignoring Omarchy')
    args = parser.parse_args()
    required, command_groups = validate(args.profile)
    print(f'PASS: {len(required)} selected package declarations and executable-provider coverage ({args.profile})')
    if args.check_repos:
        result = subprocess.run(['pacman', '-Sl', 'core', 'extra', 'multilib'], text=True, capture_output=True, check=True)
        names = {line.split()[1] for line in result.stdout.splitlines()}
        missing = (manifest('core.official') | manifest('personal.official')) - names
        assert not missing, f'Missing official packages: {sorted(missing)}'
        print('PASS: All official entries exist in cached Arch databases (no refresh performed)')
    if args.installed:
        installed = set(subprocess.check_output(['pacman', '-Qqe'], text=True).splitlines())
        groups = tomllib.loads((REPO / 'packages/omissions.toml').read_text())['groups']
        accounted = selected('personal') | {'yay', 'yay-bin'}
        for name, group in groups.items():
            found = installed & set(group['packages'])
            accounted.update(group['packages'])
            if found:
                print(f'{name}: {", ".join(sorted(found))}\n  {group["reason"]}')
        unknown = installed - accounted
        assert not unknown, f'Unclassified installed explicit packages: {sorted(unknown)}'
        print(f'PASS: All {len(installed)} installed explicit packages accounted for; omissions are not removals')
    if args.packages:
        result = subprocess.run(['pacman', '-T', *sorted(required)], text=True, capture_output=True)
        assert result.returncode == 0, f'Missing packages/providers: {result.stdout or result.stderr}'
    if args.commands:
        commands = dict(command_groups['commands'])
        if args.profile == 'personal':
            commands.update(command_groups['personal_commands'])
        missing = [name for name in commands if not shutil.which(name)]
        assert not missing, f'Missing executable commands: {missing}'
        print('PASS: Selected desktop/helper/runtime commands found in current PATH')


if __name__ == '__main__':
    main()
