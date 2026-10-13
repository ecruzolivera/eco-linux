#!/usr/bin/env python3
"""Safe installer tests: disposable homes, inert module fixtures and mocked tools."""
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
BASE_ENV = {**os.environ, 'PATH': '/usr/bin:/bin', 'PYTHONDONTWRITEBYTECODE': '1'}
sys.dont_write_bytecode = True


class InstallerTests(unittest.TestCase):
    def setUp(self):
        parent = Path('/tmp/opencode')
        self.temporary = tempfile.TemporaryDirectory(prefix='eco-installer-test-', dir=parent if parent.is_dir() else None)
        self.root = Path(self.temporary.name)
        self.home = self.root / 'other user & home|path'
        self.home.mkdir()

    def tearDown(self):
        self.temporary.cleanup()

    def bash(self, code, **kwargs):
        return subprocess.run(['/bin/bash', '-Eeuo', 'pipefail', '-c', code],
                              env={**BASE_ENV, 'HOME': str(self.home)}, text=True, capture_output=True, **kwargs)

    def deploy(self, mode='replace', profile='portable', success=True):
        env = {**BASE_ENV, 'HOME': str(self.home), 'REAL_HOME': str(self.home),
               'USER_CONFIG': str(self.home / '.config'), 'ECO_CONFIG_MODE': mode, 'ECO_PROFILE': profile}
        for group, variable in [
            ('xdg-config', 'INSTALLER_XDG_CONFIG_DIR'), ('home-root-config', 'INSTALLER_HOME_ROOT_CONFIG_DIR'),
            ('local-bin', 'INSTALLER_LOCAL_BIN_DIR'), ('local-share', 'INSTALLER_LOCAL_SHARE_DIR'),
        ]:
            env[variable] = str(REPO / group)
        result = subprocess.run(['/usr/bin/python3', str(REPO / 'lib/deploy-config.py')], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result

    def test_defaults_and_invalid_option(self):
        result = self.bash(f'''error() {{ exit 2; }}; source "{REPO}/lib/installer.sh"
            parse_options
            printf '%s %s %s %s %s\\n' "$ECO_PROFILE" "$ECO_APPS" "$ECO_CONFIG_MODE" "$ECO_NETWORK" "$ECO_AUTOLOGIN"
        ''')
        self.assertEqual(result.stdout.strip(), 'portable personal preserve preserve 0')
        result = self.bash(f'error() {{ exit 2; }}; source "{REPO}/lib/installer.sh"; parse_options --profile invalid')
        self.assertEqual(result.returncode, 2)

    def fixture(self):
        repo = self.root / 'checkout with spaces'
        (repo / 'scripts').mkdir(parents=True)
        shutil.copy2(REPO / 'install.sh', repo / 'install.sh')
        shutil.copytree(REPO / 'lib', repo / 'lib')
        bins = self.root / 'bin'
        bins.mkdir()
        (bins / 'id').write_text('#!/bin/sh\nprintf "0\\n"\n')
        (bins / 'id').chmod(0o755)
        (bins / 'sudo').write_text('#!/bin/sh\nexit 91\n')
        (bins / 'sudo').chmod(0o755)
        env = {**BASE_ENV, 'PATH': f'{bins}:/usr/bin:/bin', 'ECO_TEST_LOG': str(self.root / 'calls')}
        return repo, env

    def test_entrypoint_absolute_paths_and_changed_cwd(self):
        repo, env = self.fixture()
        (repo / 'scripts/00-checks.sh').write_text('printf "checks\\n" >> "$ECO_TEST_LOG"\n')
        (repo / 'scripts/02-yay.sh').write_text('cd /\nprintf "yay\\n" >> "$ECO_TEST_LOG"\n')
        (repo / 'scripts/03-packages.sh').write_text('printf "packages:%s\\n" "$ECO_APPS" >> "$ECO_TEST_LOG"\n')
        for _ in range(2):
            result = subprocess.run(['/bin/bash', str(repo / 'install.sh'), '--apps', 'core'], cwd=self.home,
                                    env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'calls').read_text().splitlines(), ['checks', 'yay', 'packages:core'] * 2)

    def test_failure_and_signal_stop_following_modules(self):
        for failure, code in [('false', 1), ('kill -TERM $$', 143), ('kill -INT $$', 130)]:
            with self.subTest(failure=failure):
                # Unique fixture for each signal; no real modules ever execute.
                with tempfile.TemporaryDirectory(dir=self.root) as path:
                    inner = Path(path)
                    repo = inner / 'checkout'
                    (repo / 'scripts').mkdir(parents=True)
                    shutil.copy2(REPO / 'install.sh', repo / 'install.sh')
                    shutil.copytree(REPO / 'lib', repo / 'lib')
                    (repo / 'scripts/00-checks.sh').write_text(failure + '\n')
                    (repo / 'scripts/01-system.sh').write_text(f'touch "{inner}/unexpected"\n')
                    bins = inner / 'bin'
                    bins.mkdir()
                    (bins / 'id').write_text('#!/bin/sh\nprintf "0\\n"\n')
                    (bins / 'id').chmod(0o755)
                    result = subprocess.run(['/bin/bash', str(repo / 'install.sh')],
                                            env={**BASE_ENV, 'PATH': f'{bins}:/usr/bin:/bin'}, text=True, capture_output=True)
                    self.assertEqual(result.returncode, code, result.stderr)
                    self.assertFalse((inner / 'unexpected').exists())
                    self.assertIn('No temporary sudo grants', result.stderr)

    def test_missing_yay_branch_scopes_cwd_and_cleanup(self):
        log = self.root / 'build-path'
        result = self.bash(f'''
            source "{REPO}/lib/installer.sh"
            info() {{ :; }}; phase() {{ :; }}; error() {{ exit 1; }}
            REAL_UID=1000 REAL_GID=1000
            command() {{ if [[ $* == '-v yay' ]]; then return 1; fi; builtin command "$@"; }}
            chown() {{ :; }}
            pacman() {{ [[ $1 == -U ]]; }}
            run_user() {{
              case $1 in
                git) mkdir -p "${{@: -1}}"; printf '# inert recipe\\n' > "${{@: -1}}/PKGBUILD"; printf '%s\\n' "${{@: -1}}" > "{log}";;
                makepkg) if [[ $2 == --packagelist ]]; then printf '%s\\n' "$PWD/yay.pkg.tar.zst"; else touch yay.pkg.tar.zst; fi;;
                *) return 98;;
              esac
            }}
            cd "{self.home}"
            before=$PWD
            source "{REPO}/scripts/02-yay.sh"
            [[ $PWD == "$before" ]]
        ''', input='y\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(Path(log.read_text().strip()).parent.exists())

    def test_preserve_replace_backups_and_permissions(self):
        self.deploy()
        cli = self.home / '.config/opencode/cli.json'
        cli.write_text('user modification\n')
        cli.chmod(0o600)
        self.deploy(mode='preserve')
        self.assertEqual(cli.read_text(), 'user modification\n')
        self.deploy(mode='replace')
        backups = list((self.home / '.local/state/eco-linux/config-backups').glob('replace-*/.config/opencode/cli.json'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'user modification\n')
        self.assertEqual(cli.stat().st_mode & 0o777, 0o600)
        self.assertEqual(backups[0].parents[2].stat().st_mode & 0o777, 0o700)
        self.deploy(mode='replace')
        self.assertEqual(len(list((self.home / '.local/state/eco-linux/config-backups').glob('replace-*'))), 1)

    def test_directory_symlink_refused_without_external_changes(self):
        outside = self.root / 'outside'
        outside.mkdir()
        (outside / 'sentinel').write_text('untouched')
        (self.home / '.config').symlink_to(outside, target_is_directory=True)
        self.deploy(success=False)
        self.assertEqual([path.name for path in outside.iterdir()], ['sentinel'])

    def test_optional_machine_profile(self):
        self.deploy(profile='ernesto')
        for relative in ['niri/monitors.kdl', 'niri/workspaces.kdl', 'DankMaterialShell/monitors.json']:
            source = REPO / 'profiles/ernesto/xdg-config' / relative
            self.assertEqual(source.read_bytes(), (self.home / '.config' / relative).read_bytes())
        self.assertIn('HDMI-A-1', (self.home / '.config/niri/monitors.kdl').read_text())

    def test_nvidia_selection(self):
        result = self.bash(f'''source "{REPO}/lib/installer.sh"
          select_nvidia 'Intel GPU' '' auto
          select_nvidia 'NVIDIA T600 Mobile' '' auto
          select_nvidia 'NVIDIA GTX 1080' '' auto
          select_nvidia 'NVIDIA T600 Mobile' 'nvidia-open-dkms' auto
          select_nvidia 'NVIDIA T600 Mobile' '' off
          select_nvidia $'NVIDIA T600 Mobile\nNVIDIA GTX 1080' '' auto
        ''')
        self.assertEqual(result.stdout.splitlines(), ['off', 'open', 'manual', 'existing', 'off', 'manual'])

    def test_pinned_integration_prompts_read_terminal_not_manifest(self):
        repo = self.root / 'pinned-repo'
        shutil.copytree(REPO / 'packages', repo / 'packages')
        lock = repo / 'packages/integrations.lock'
        lock.write_text('# reviewed pair\n'
                        'herdr-bin 0a0694ee84e9a41920ea8d977b0f97bd5d0469e3 0.9.3-1\n'
                        'opencode-beta cb54ab34b079a556f550d772f504d2d93db3973b 2.0.26-1\n')
        marker = self.root / 'pinned-markers'
        marker.mkdir()
        result = self.bash(f'''
            INSTALLER_DIR="{repo}" ECO_APPS=personal
            REAL_UID=1000 REAL_GID=1000
            phase() {{ :; }}; info() {{ :; }}; warn() {{ :; }}
            error() {{ printf 'error: %s\\n' "$*" >&2; exit 42; }}
            read_manifest() {{ printf '\\n'; }}
            install_aur() {{ return 0; }}
            chown() {{ :; }}
            mktemp() {{ printf '%s\\n' "{marker}/eco-build"; }}
            run_user() {{
              case $1 in
                git)
                  if [[ $2 == clone ]]; then
                    mkdir -p "${{@: -1}}"
                    name=$3; name=${{name%.git}}; name=${{name##*/}}
                    printf '%s\\n' "$name" > "{marker}/current-name"
                    printf '# inert recipe\\n' > "${{@: -1}}/PKGBUILD"
                  fi;;
                makepkg)
                  name=$(cat "{marker}/current-name")
                  if [[ $2 == --packagelist ]]; then printf '%s\\n' "$PWD/$name.pkg.tar.zst"; fi;;
                *) return 98;;
              esac
            }}
            pacman() {{
              case $1 in
                -S) return 0;;
                -Q) [[ -f "{marker}/installed-$2" ]] || return 1
                    case $2 in
                      herdr-bin) printf 'herdr-bin 0.9.3-1\\n';;
                      opencode-beta) printf 'opencode-beta 2.0.26-1\\n';;
                    esac;;
                -U) touch "{marker}/installed-$(cat {marker}/current-name)";;
                *) return 98;;
              esac
            }}
            cd "{self.root}"
            source "{REPO}/scripts/03-packages.sh"
            printf 'complete\\n' >> "{marker}/done"
        ''', input='y\ny\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((marker / 'installed-herdr-bin').exists())
        self.assertTrue((marker / 'installed-opencode-beta').exists())
        self.assertEqual((marker / 'done').read_text().strip(), 'complete')

    def test_no_database_only_upgrades_or_sudoers_writes(self):
        scripts = '\n'.join(path.read_text() for path in (REPO / 'scripts').glob('*.sh'))
        self.assertNotRegex(scripts, r'pacman -Sy(?:\s|$)')
        self.assertIn('pacman -Syu --needed', scripts)
        self.assertNotIn('NOPASSWD', scripts)
        self.assertNotRegex(scripts, r'>\s*/etc/sudoers')
        self.assertNotIn('chown -', (REPO / 'scripts/zz-final.sh').read_text())

    def herdr_module(self):
        spec = importlib.util.spec_from_file_location('eco_bootstrap_herdr', REPO / 'lib/bootstrap-herdr.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_reviewed_plugin_rerun_does_not_reinstall(self):
        module = self.herdr_module()
        local = self.home / '.config/herdr/plugins/local/eco-ws-number'
        plugins = {'eco.ws-number': {'plugin_root': str(local)}}
        roots = {}
        for plugin_id, repository, revision in module.PLUGINS:
            owner, repo = repository.split('/')
            root = str(self.root / plugin_id)
            roots[root] = revision
            plugins[plugin_id] = {'plugin_root': root, 'source': {
                'kind': 'github', 'resolved_commit': revision, 'owner': owner, 'repo': repo}}
        with mock.patch.object(module.Path, 'home', return_value=self.home), \
                mock.patch.object(module, 'installed', return_value=plugins), \
                mock.patch.object(module.subprocess, 'check_output', side_effect=lambda argv, **_: roots[argv[2]] if argv[-1] == 'HEAD' else ''), \
                mock.patch.object(module.subprocess, 'run') as run:
            module.bootstrap()
            module.bootstrap()
            run.assert_not_called()

    def test_unreviewed_plugin_is_not_overwritten(self):
        module = self.herdr_module()
        plugins = {
            'eco.ws-number': {'plugin_root': str(self.home / '.config/herdr/plugins/local/eco-ws-number')},
            module.PLUGINS[0][0]: {'source': {'kind': 'github', 'resolved_commit': 'unreviewed'}},
        }
        with mock.patch.object(module.Path, 'home', return_value=self.home), \
                mock.patch.object(module, 'installed', return_value=plugins), \
                mock.patch.object(module.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'unreviewed existing plugin preserved'):
                module.bootstrap()
            run.assert_not_called()

    def test_declined_plugin_install_is_incomplete(self):
        module = self.herdr_module()
        plugins = {'eco.ws-number': {'plugin_root': str(self.home / '.config/herdr/plugins/local/eco-ws-number')}}
        with mock.patch.object(module.Path, 'home', return_value=self.home), \
                mock.patch.object(module, 'installed', return_value=plugins), \
                mock.patch.object(module.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'declined'):
                module.bootstrap()
            self.assertEqual(run.call_args.args[0], ['herdr', 'plugin', 'install', module.PLUGINS[0][1], '--ref', module.PLUGINS[0][2]])

    def mock_user_setup(self, has_toolchain=True, component_exit=0, analyzer_exit=0):
        calls = self.root / 'user-calls'
        config = self.home / '.config/nvim'
        config.mkdir(parents=True)
        (config / 'lazy-lock.json').write_text('{}')
        mocks = f'''
          id() {{ printf '1000\\n'; }}
          mise() {{
            case $1 in env) printf ':\\n';; where) printf '/fake/java\\n';;
              *) printf 'mise:%s\\n' "$1" >> "{calls}";; esac
          }}
          java() {{ printf 'openjdk version "21.0.12"\\n' >&2; }}
          javac() {{ :; }}; npm() {{ :; }}; npx() {{ :; }}
          node() {{ printf 'node:%s\\n' "$1" >> "{calls}"; }}
          bun() {{ :; }}; go() {{ :; }}
          rustup() {{
            printf 'rustup:%s\n' "$*" >> "{calls}"
            case $1 in
              show) return {0 if has_toolchain else 1};;
              default) [[ $* == 'default stable' ]];;
              component) [[ $* == 'component add rust-analyzer rust-src' ]] || return 98
                         return {component_exit};;
              *) return 98;;
            esac
          }}
          rust-analyzer() {{
            [[ $* == --version ]] || return 98
            printf 'rust-analyzer:%s\n' "$*" >> "{calls}"
            printf 'rust-analyzer mock\n'
            return {analyzer_exit}
          }}
          nvim() {{ :; }}; timeout() {{ :; }}
          herdr() {{ printf 'herdr 0.9.3\\n'; }}
          opencode() {{ printf 'opencode v2.0.27\\n'; }}
          python3() {{ printf 'python:%s\\n' "$1" >> "{calls}"; }}
          source "{REPO}/lib/user-setup.sh" "{REPO}"
        '''
        return self.bash(mocks), calls

    def test_user_setup_checks_versions_before_plugin_or_patch_changes(self):
        result, calls = self.mock_user_setup()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unreviewed integration versions', result.stderr)
        self.assertNotIn('bootstrap-herdr.py', calls.read_text())
        self.assertNotIn('node:--apply', calls.read_text())
        self.assertIn('INCOMPLETE: integration-version-check', (self.home / '.local/state/eco-linux/user-setup.txt').read_text())
        self.assertEqual(list((self.home / '.local/state/eco-linux').glob('nvim-lock.*')), [])

    def test_user_setup_installs_and_checks_rust_editor_components(self):
        result, calls = self.mock_user_setup(has_toolchain=False)
        self.assertIn('Unreviewed integration versions', result.stderr)
        log = calls.read_text().splitlines()
        self.assertIn('rustup:default stable', log)
        components = log.index('rustup:component add rust-analyzer rust-src')
        analyzer = log.index('rust-analyzer:--version')
        editor = log.index(f'python:{REPO}/lib/check-nvim-worktrees.py')
        self.assertLess(log.index('rustup:default stable'), components)
        self.assertLess(components, analyzer)
        self.assertLess(analyzer, editor)
        self.assertIn('rust-analyzer mock', (self.home / '.local/state/eco-linux/user-setup.txt').read_text())

    def test_user_setup_preserves_existing_rust_toolchain(self):
        result, calls = self.mock_user_setup()
        self.assertIn('Unreviewed integration versions', result.stderr)
        self.assertNotIn('rustup:default stable', calls.read_text())
        self.assertIn('rustup:component add rust-analyzer rust-src', calls.read_text())
        self.assertIn('rust-analyzer:--version', calls.read_text())

    def test_user_setup_stops_on_rust_component_failure(self):
        result, calls = self.mock_user_setup(component_exit=41)
        self.assertEqual(result.returncode, 41, result.stderr)
        self.assertNotIn('rust-analyzer:--version', calls.read_text())
        self.assertNotIn('check-nvim-worktrees.py', calls.read_text())
        self.assertIn('INCOMPLETE: rust-toolchain', (self.home / '.local/state/eco-linux/user-setup.txt').read_text())

    def test_user_setup_refuses_nonworking_rust_analyzer_proxy(self):
        result, calls = self.mock_user_setup(analyzer_exit=42)
        self.assertEqual(result.returncode, 42, result.stderr)
        self.assertIn('rust-analyzer:--version', calls.read_text())
        self.assertNotIn('check-nvim-worktrees.py', calls.read_text())
        self.assertIn('INCOMPLETE: rust-toolchain', (self.home / '.local/state/eco-linux/user-setup.txt').read_text())

    def test_standalone_root_refused_before_download(self):
        path = self.root / 'standalone.sh'
        shutil.copy2(REPO / 'install.sh', path)
        bins = self.root / 'bin'
        bins.mkdir()
        (bins / 'id').write_text('#!/bin/sh\nprintf "0\\n"\n')
        (bins / 'id').chmod(0o755)
        calls = self.root / 'bootstrap-calls'
        for command in ['curl', 'tar', 'mktemp', 'sudo', 'pacman']:
            mock_command = bins / command
            mock_command.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >> "$ECO_TEST_LOG"\nexit 91\n')
            mock_command.chmod(0o755)
        env = {**BASE_ENV, 'PATH': f'{bins}:/usr/bin:/bin', 'SUDO_USER': 'target', 'ECO_TEST_LOG': str(calls)}
        result = subprocess.run(['/bin/bash', str(path), '--ref', 'reviewed-commit'],
                                env=env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('without sudo', result.stderr)
        self.assertFalse(calls.exists())
        result = subprocess.run(['/bin/bash', str(path), '--help'], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Standalone bootstrap:', result.stdout)
        self.assertFalse(calls.exists())

    def test_remote_bootstrap_requires_revision_before_network(self):
        path = self.root / 'standalone.sh'
        shutil.copy2(REPO / 'install.sh', path)
        result = subprocess.run(['/bin/bash', str(path)], env=BASE_ENV, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('requires --ref', result.stderr)

    def test_malformed_manifest_stops_before_package_installation(self):
        repo = self.root / 'malformed-repo'
        shutil.copytree(REPO / 'packages', repo / 'packages')
        (repo / 'packages/core.official').write_text('git\nnot a valid name\n')
        calls = self.root / 'pacman-calls'
        result = self.bash(f'''
          source "{REPO}/lib/installer.sh"
          phase() {{ :; }}; error() {{ exit 2; }}
          INSTALLER_DIR="{repo}" ECO_APPS=personal
          pacman() {{ touch "{calls}"; }}
          source "{REPO}/scripts/03-packages.sh"
        ''')
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertFalse(calls.exists())

    def test_editor_plugin_edits_and_symlinks_are_preserved(self):
        spec = importlib.util.spec_from_file_location('eco_check_nvim', REPO / 'lib/check-nvim-worktrees.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        root = self.root / 'plugins'
        plugin = root / 'edited-plugin'
        (plugin / '.git').mkdir(parents=True)
        with mock.patch.object(module.subprocess, 'check_output', return_value=' M file.lua\n'):
            with self.assertRaisesRegex(RuntimeError, 'Plugin edits/untracked files preserved'):
                module.check(root)
        linked = self.root / 'linked-plugins'
        linked.symlink_to(root, target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, 'symlink'):
            module.check(linked)


if __name__ == '__main__':
    unittest.main(verbosity=2)
