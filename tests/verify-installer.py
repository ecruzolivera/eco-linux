#!/usr/bin/env python3
"""Safe installer tests: disposable homes, inert module fixtures and mocked tools."""
import importlib.util
import fcntl
import os
import pty
import select
import shutil
import subprocess
import sys
import tempfile
import termios
import time
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
            ECO_PROFILE=ernesto ECO_APPS=core ECO_CONFIG_MODE=preserve
            installer_defaults
            printf '%s %s %s %s\\n' "$ECO_PROFILE" "$ECO_APPS" "$ECO_CONFIG_MODE" "$ECO_FIREWALL"
            ECO_REMOTE_SESSION=1
            installer_defaults
            printf '%s\\n' "$ECO_FIREWALL"
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['portable personal replace enable', 'preserve'])
        repo, env = self.fixture()
        marker = self.root / 'unexpected'
        (repo / 'scripts/00-checks.sh').write_text(f'touch "{marker}"\n')
        result = subprocess.run(['/bin/bash', str(repo / 'install.sh'), '--profile', 'portable'],
                                env=env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('No installation options', result.stderr)
        self.assertFalse(marker.exists())

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
            result = subprocess.run(['/bin/bash', str(repo / 'install.sh')], cwd=self.home,
                                    env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'calls').read_text().splitlines(), ['checks', 'yay', 'packages:personal'] * 2)

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

    def test_aur_install_is_noninteractive_without_changing_saved_settings(self):
        result = self.bash(f'''
            source "{REPO}/lib/installer.sh"
            run_user() {{
              printf '%s\\n' "$@"
            }}
            install_aur brave-bin worktrunk-bin
        ''', input='')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            'env', 'PAGER=cat', 'GIT_PAGER=cat', 'yay', '-S', '--needed', '--aur', '--noconfirm',
            '--answerclean', 'None', '--answerdiff', 'All', '--answeredit', 'None', '--noremovemake',
            '--editmenu=false', '--useask=false', '--pgpfetch', '--batchinstall',
            'brave-bin', 'worktrunk-bin',
        ])

    def test_empty_aur_list_does_not_invoke_yay(self):
        result = self.bash(f'''
            source "{REPO}/lib/installer.sh"
            run_user() {{ printf 'unexpected invocation\\n'; return 98; }}
            install_aur
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '')

    def test_normal_user_commands_disable_git_credential_prompts(self):
        result = self.bash(f'''
            source "{REPO}/lib/installer.sh"
            REAL_USER=target REAL_HOME="{self.home}"
            sudo() {{
              [[ ${{*:1:3}} == '-u target -H' ]] || return 98
              shift 3
              "$@"
            }}
            export GIT_TERMINAL_PROMPT=1
            run_user bash -c '[[ $GIT_TERMINAL_PROMPT == 0 && $HOME == "$1" && $USER == target ]]' bash "$REAL_HOME"
        ''', input='')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_yay_branch_scopes_cwd_and_cleanup(self):
        log = self.root / 'build-path'
        result = self.bash(f'''
            source "{REPO}/lib/installer.sh"
            info() {{ :; }}; phase() {{ :; }}; error() {{ exit 1; }}
            REAL_UID=1000 REAL_GID=1000
            command() {{ if [[ $* == '-v yay' ]]; then return 1; fi; builtin command "$@"; }}
            chown() {{ :; }}
            pacman() {{ [[ ${{*:1:3}} == '-U --needed --noconfirm' ]]; }}
            run_user() {{
              case $1 in
                git) mkdir -p "${{@: -1}}"; printf '# inert recipe\\n' > "${{@: -1}}/PKGBUILD"; printf '%s\\n' "${{@: -1}}" > "{log}";;
                makepkg) if [[ $2 == --packagelist ]]; then printf '%s\\n' "$PWD/yay.pkg.tar.zst"
                         else [[ $* == 'makepkg --syncdeps --cleanbuild --noconfirm' ]] || return 98
                              touch yay.pkg.tar.zst; fi;;
                *) return 98;;
              esac
            }}
            cd "{self.home}"
            before=$PWD
            source "{REPO}/scripts/02-yay.sh"
            [[ $PWD == "$before" ]]
        ''', input='')
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

    def configure_sddm_fixture(self, user='target'):
        # Only the disposable path is writable; never source the real /etc-writing module.
        script = (REPO / 'scripts/04-sddm.sh').read_text().replace('/etc/sddm.conf.d', str(self.root / 'sddm'))
        return self.bash(f'''
          phase() {{ :; }}; info() {{ :; }}
          warn() {{ printf '%s\\n' "$*" >&2; }}
          error() {{ printf '%s\\n' "$*" >&2; exit 46; }}
          REAL_USER={user}
          INSTALLER_SYS_CONFIG_DIR="{REPO}/system-config"
          source /dev/stdin
        ''', input=script)

    def test_sddm_autologin_uses_target_user_and_is_idempotent(self):
        result = self.configure_sddm_fixture(user='other-user')
        self.assertEqual(result.returncode, 0, result.stderr)
        configuration = self.root / 'sddm/autologin.conf'
        self.assertEqual(configuration.read_text(), '[Autologin]\nUser=other-user\nSession=niri.desktop\n')
        self.assertEqual(configuration.stat().st_mode & 0o777, 0o644)
        self.assertIn('encrypted login keyrings', result.stderr)
        before = configuration.stat().st_mtime_ns
        result = self.configure_sddm_fixture(user='other-user')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(configuration.stat().st_mtime_ns, before)
        self.assertEqual(list(configuration.parent.glob('autologin.conf.eco.*')), [])

    def test_sddm_autologin_backs_up_changed_existing_configuration(self):
        directory = self.root / 'sddm'
        directory.mkdir()
        configuration = directory / 'autologin.conf'
        previous = '[Autologin]\nUser=previous\nSession=other.desktop\n'
        configuration.write_text(previous)
        configuration.chmod(0o640)
        unrelated = directory / 'theme.conf'
        unrelated.write_text('existing theme\n')
        result = self.configure_sddm_fixture()
        self.assertEqual(result.returncode, 0, result.stderr)
        backups = list(directory.glob('autologin.conf.eco.*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), previous)
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o640)
        self.assertIn('User=target\n', configuration.read_text())
        result = self.configure_sddm_fixture(user='another-user')
        self.assertEqual(result.returncode, 0, result.stderr)
        backups = list(directory.glob('autologin.conf.eco.*'))
        self.assertEqual(len(backups), 2)
        self.assertIn('[Autologin]\nUser=target\nSession=niri.desktop\n', [p.read_text() for p in backups])
        self.assertEqual(unrelated.read_text(), 'existing theme\n')

    def test_sddm_autologin_refuses_symlink_without_external_changes(self):
        directory = self.root / 'sddm'
        directory.mkdir()
        outside = self.root / 'outside-sddm'
        outside.write_text('preserved\n')
        configuration = directory / 'autologin.conf'
        configuration.symlink_to(outside)
        result = self.configure_sddm_fixture()
        self.assertEqual(result.returncode, 46, result.stderr)
        self.assertTrue(configuration.is_symlink())
        self.assertEqual(outside.read_text(), 'preserved\n')

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
          select_nvidia 'Intel GPU' ''
          select_nvidia 'NVIDIA T600 Mobile' ''
          select_nvidia 'NVIDIA GTX 1080' ''
          select_nvidia 'NVIDIA T600 Mobile' 'nvidia-open-dkms'
          select_nvidia $'NVIDIA T600 Mobile\nNVIDIA GTX 1080' ''
        ''')
        self.assertEqual(result.stdout.splitlines(), ['off', 'open', 'manual', 'existing', 'manual'])

    def test_unknown_nvidia_is_reported_without_package_changes(self):
        result = self.bash(f'''
          source "{REPO}/lib/installer.sh"
          phase() {{ :; }}; info() {{ :; }}
          warn() {{ printf '%s\\n' "$*" >&2; }}
          lspci() {{ printf 'VGA compatible controller: NVIDIA GTX 1080\\n'; }}
          pacman() {{ [[ $* == -Qq ]] || return 98; }}
          source "{REPO}/scripts/05-nvidia.sh"
          printf 'continued\\n'
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('graphics changes skipped', result.stderr)
        self.assertEqual(result.stdout.strip(), 'continued')

    def test_pinned_integrations_install_with_closed_stdin(self):
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
                    printf '# inert recipe\\n' > "${{@: -1}}/PKGBUILD"
                  fi;;
                makepkg)
                  name=${{PWD##*/}}
                  if [[ $2 == --packagelist ]]; then printf '%s\\n' "$PWD/$name.pkg.tar.zst"
                  else [[ $* == 'makepkg --syncdeps --cleanbuild --noconfirm' ]] || return 98; fi;;
                *) return 98;;
              esac
            }}
            pacman() {{
              case $1 in
                -S) [[ ${{*:1:3}} == '-S --needed --noconfirm' ]];;
                -Q) [[ -f "{marker}/installed-$2" ]] || return 1
                    case $2 in
                      herdr-bin) printf 'herdr-bin 0.9.3-1\\n';;
                      opencode-beta) printf 'opencode-beta 2.0.26-1\\n';;
                    esac;;
                -U) [[ ${{*:1:3}} == '-U --needed --noconfirm' ]] || return 98
                    touch "{marker}/installed-${{PWD##*/}}";;
                *) return 98;;
              esac
            }}
            cd "{self.root}"
            source "{REPO}/scripts/03-packages.sh"
            printf 'complete\\n' >> "{marker}/done"
        ''', input='')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((marker / 'installed-herdr-bin').exists())
        self.assertTrue((marker / 'installed-opencode-beta').exists())
        self.assertEqual((marker / 'done').read_text().strip(), 'complete')
        output = result.stdout + result.stderr
        # Recipes remain visible, but EOF on stdin must not stop installation.
        for name in ['herdr-bin 0.9.3-1', 'opencode-beta 2.0.26-1']:
            self.assertIn(f'reviewed integration recipe: {name}', output)

    def test_pinned_integration_build_failure_stops_before_installation(self):
        repo = self.root / 'failed-repo'
        shutil.copytree(REPO / 'packages', repo / 'packages')
        marker = self.root / 'failed-markers'
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
                git) case $2 in
                       clone) mkdir -p "${{@: -1}}"
                              printf '# inert recipe\\n' > "${{@: -1}}/PKGBUILD";;
                       -C) :;;
                       *) return 98;;
                     esac;;
                makepkg) [[ $* == 'makepkg --syncdeps --cleanbuild --noconfirm' ]] || return 98
                         touch "{marker}/built-any"; return 43;;
                *) return 98;;
              esac
            }}
            pacman() {{
              case $1 in
                -S) return 0;;
                -Q) return 1;;
                -U) touch "{marker}/installed-any";;
                *) return 98;;
              esac
            }}
            cd "{self.root}"
            source "{REPO}/scripts/03-packages.sh"
            printf 'complete\\n' >> "{marker}/done"
        ''', input='')
        self.assertEqual(result.returncode, 43, result.stderr)
        self.assertTrue((marker / 'built-any').exists())
        self.assertFalse((marker / 'installed-any').exists())
        self.assertFalse((marker / 'done').exists())

    def test_network_detection_preserves_active_or_enabled_manager(self):
        for service in ['NetworkManager', 'systemd-networkd', 'iwd', 'dhcpcd', 'connman', 'netctl',
                        'dhcpcd@eth0', 'netctl@home', 'netctl-auto@wlan0', 'netctl-ifplugd@eth0', 'unrelated']:
            for state in ['list-units', 'list-unit-files']:
                with self.subTest(service=service, state=state):
                    result = self.bash(f'''
                      source "{REPO}/lib/installer.sh"
                      systemctl() {{
                        if [[ $1 == '{state}' ]]; then printf '{service}.service loaded active running\\n'; fi
                      }}
                      select_network
                    ''')
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), 'networkmanager' if service == 'unrelated' else 'preserve')

    def test_network_detection_failure_is_not_treated_as_missing_manager(self):
        result = self.bash(f'''
          source "{REPO}/lib/installer.sh"
          systemctl() {{ return 45; }}
          network=$(select_network)
          printf 'unexpected:%s\\n' "$network"
        ''')
        self.assertEqual(result.returncode, 45, result.stderr)
        self.assertEqual(result.stdout, '')

    def test_networkmanager_enablement_rechecks_network_and_never_starts_it(self):
        docker = self.root / 'docker'
        docker.mkdir()
        for selection in ['preserve', 'networkmanager']:
            with self.subTest(selection=selection):
                log = self.root / 'network-calls'
                log.write_text('')
                result = self.bash(f'''
                  phase() {{ :; }}; info() {{ :; }}; warn() {{ :; }}
                  ECO_NETWORK=networkmanager REAL_USER=target
                  select_network() {{ printf '%s\\n' '{selection}'; }}
                  mkdir() {{ :; }}; usermod() {{ :; }}
                  systemctl() {{ printf '%s\\n' "$*" >> "{log}"; }}
                  source /dev/stdin
                ''', input=(REPO / 'scripts/09-docker.sh').read_text().replace('/etc/docker', str(docker)))
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = log.read_text().splitlines()
                self.assertEqual('enable NetworkManager' in calls, selection == 'networkmanager')
                self.assertFalse(any('--now' in call or call.startswith('start ') for call in calls))

    def piped_bootstrap_fixture(self):
        repo, env = self.fixture()
        (repo / 'scripts/00-checks.sh').write_text('''
          [[ -t 0 && -t 1 ]]
          read -r -p 'FIXTURE_CONFIRM: ' answer
          [[ $answer == approve ]]
          printf 'confirmed:%s:%s:%s:%s\n' "$answer" "$ECO_APPS" "$ECO_CONFIG_MODE" "$ECO_FIREWALL" >> "$ECO_TEST_LOG"
        ''')
        (repo / 'scripts/zz-final.sh').write_text('printf "complete\\n" >> "$ECO_TEST_LOG"\n[[ ${ECO_TEST_INSTALL_EXIT:-0} == 0 ]] || exit "$ECO_TEST_INSTALL_EXIT"\n')
        bins = self.root / 'bin'
        (bins / 'id').write_text('#!/bin/sh\nif [ "${ECO_TEST_ELEVATED:-0}" = 1 ]; then printf "0\\n"; else printf "1000\\n"; fi\n')
        (bins / 'sudo').write_text('''#!/bin/bash
set -euo pipefail
[[ -t 0 ]]
printf 'sudo:%s\n' "$*" >> "$ECO_TEST_LOG"
export ECO_TEST_ELEVATED=1
unset SSH_CONNECTION SSH_CLIENT SSH_TTY
exec "$@"
''')
        git = bins / 'git'
        git.write_text('''#!/bin/bash
set -euo pipefail
[[ -t 0 ]]
case $1 in
  clone)
    [[ $# == 7 && $2 == --depth && $3 == 1 && $4 == --branch && $5 == master && $6 == https://github.com/ecruzolivera/eco-linux.git ]]
    printf 'download:%s\n' "${7%/repo}" >> "$ECO_TEST_LOG"
    if [[ ${ECO_TEST_CLONE_SIGNAL:-} == TERM ]]; then kill -TERM "$PPID"; exit 0; fi
    [[ ${ECO_TEST_CLONE_EXIT:-0} == 0 ]] || exit "$ECO_TEST_CLONE_EXIT"
    cp -R -- "$ECO_TEST_CHECKOUT" "$7";;
  -C)
    [[ $3 == rev-parse && $4 == HEAD ]]
    printf '0516e640516e640516e640516e640516e640516e64\n';;
  *) exit 98;;
esac
''')
        git.chmod(0o755)
        env['ECO_TEST_CHECKOUT'] = str(repo)
        for name in ['SSH_CONNECTION', 'SSH_CLIENT', 'SSH_TTY', 'ECO_REMOTE_SESSION']:
            env.pop(name, None)
        return repo, env

    def run_piped_bootstrap(self, env, script=None, cwd=None):
        """A real stdin pipe plus a controlling PTY; every privileged command is mocked."""
        master, slave = pty.openpty()

        def controlling_terminal():
            os.setsid()
            fcntl.ioctl(1, termios.TIOCSCTTY, 0)

        process = subprocess.Popen(['/bin/bash'], stdin=subprocess.PIPE, stdout=slave, stderr=slave,
                                   cwd=cwd or self.home, env=env, preexec_fn=controlling_terminal)
        os.close(slave)
        output = bytearray()
        try:
            process.stdin.write((script if script is not None else (REPO / 'install.sh').read_text()).encode())
            process.stdin.close()
            os.write(master, b'approve\n')
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                ready, _, _ = select.select([master], [], [], max(0, deadline - time.monotonic()))
                if not ready:
                    break
                try:
                    chunk = os.read(master, 65536)
                except OSError:
                    break  # Linux PTYs signal EOF with EIO.
                if not chunk:
                    break
                output.extend(chunk)
            process.wait(timeout=max(0.1, deadline - time.monotonic()))
            return process.returncode, output.decode(errors='replace')
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)

    def assert_bootstrap_download_cleaned(self):
        calls = (self.root / 'calls').read_text().splitlines()
        download = next(line.removeprefix('download:') for line in calls if line.startswith('download:'))
        self.assertFalse(Path(download).exists(), 'Bootstrap must clean only its owned temporary checkout')
        return calls

    def test_piped_bootstrap_uses_terminal_and_not_callers_checkout(self):
        repo, env = self.piped_bootstrap_fixture()
        code, output = self.run_piped_bootstrap(env, cwd=repo)
        self.assertEqual(code, 0, output)
        calls = self.assert_bootstrap_download_cleaned()
        self.assertIn('confirmed:approve:personal:replace:enable', calls)
        self.assertIn('complete', calls)
        self.assertIn('Installing eco-linux revision', output)
        self.assertTrue(repo.exists(), 'The original fixture checkout must not be removed')

    def test_piped_bootstrap_preserves_ssh_firewall_after_sudo(self):
        _, env = self.piped_bootstrap_fixture()
        env['SSH_CONNECTION'] = '192.0.2.1 1234 192.0.2.2 22'
        code, output = self.run_piped_bootstrap(env)
        self.assertEqual(code, 0, output)
        self.assertIn('confirmed:approve:personal:replace:preserve', self.assert_bootstrap_download_cleaned())

    def test_piped_bootstrap_clone_failure_never_runs_installer(self):
        _, env = self.piped_bootstrap_fixture()
        env['ECO_TEST_CLONE_EXIT'] = '43'
        code, output = self.run_piped_bootstrap(env)
        self.assertEqual(code, 43, output)
        calls = self.assert_bootstrap_download_cleaned()
        self.assertFalse(any(line.startswith('sudo:') or line.startswith('confirmed:') for line in calls))

    def test_piped_bootstrap_propagates_installer_failure_and_cleans_up(self):
        _, env = self.piped_bootstrap_fixture()
        env['ECO_TEST_INSTALL_EXIT'] = '44'
        code, output = self.run_piped_bootstrap(env)
        self.assertEqual(code, 44, output)
        self.assertIn('complete', self.assert_bootstrap_download_cleaned())

    def test_interrupted_piped_bootstrap_cleans_up_before_provisioning(self):
        _, env = self.piped_bootstrap_fixture()
        env['ECO_TEST_CLONE_SIGNAL'] = 'TERM'
        code, output = self.run_piped_bootstrap(env)
        self.assertEqual(code, 143, output)
        calls = self.assert_bootstrap_download_cleaned()
        self.assertFalse(any(line.startswith('sudo:') or line.startswith('confirmed:') for line in calls))

    def test_incomplete_piped_script_does_not_start_bootstrap(self):
        _, env = self.piped_bootstrap_fixture()
        source = (REPO / 'install.sh').read_text()
        source = source[:source.rindex('main "$@"')]
        code, output = self.run_piped_bootstrap(env, script=source)
        self.assertEqual(code, 0, output)
        self.assertFalse((self.root / 'calls').exists())

    def test_no_database_only_upgrades_or_sudoers_writes(self):
        scripts = '\n'.join(path.read_text() for path in (REPO / 'scripts').glob('*.sh'))
        self.assertNotRegex(scripts, r'pacman -Sy(?:\s|$)')
        self.assertIn('pacman -Syu --needed --noconfirm', scripts)
        self.assertIn('pacman -S --needed --noconfirm', scripts)
        self.assertIn('pacman -U --needed --noconfirm', scripts)
        self.assertNotIn('NOPASSWD', scripts)
        self.assertNotRegex(scripts, r'>\s*/etc/sudoers')
        self.assertNotIn('chown -', (REPO / 'scripts/zz-final.sh').read_text())
        # Preflight must not refresh sudo interactively; it inspects the policy as root.
        self.assertNotIn('sudo -v', scripts)
        self.assertIn('sudo -l -U "$REAL_USER"', scripts)
        # No installer-authored approval prompt may return in any module.
        shell_sources = scripts + (REPO / 'install.sh').read_text() + '\n'.join(
            path.read_text() for path in (REPO / 'lib').glob('*.sh'))
        self.assertNotRegex(shell_sources, r'\bread\b[^\n]*\s-[^\s]*p(?:\s|$)')
        # AUR dependency installs and yay housekeeping must never wait on a menu or pager.
        self.assertNotRegex(scripts, r'makepkg --syncdeps --cleanbuild(?!\s+--noconfirm)')
        self.assertIn('--answerdiff All', (REPO / 'lib/installer.sh').read_text())
        self.assertIn('--noremovemake', (REPO / 'lib/installer.sh').read_text())
        self.assertIn('PAGER=cat GIT_PAGER=cat', (REPO / 'lib/installer.sh').read_text())
        self.assertNotRegex(shell_sources, r'--skip(checksums|pgpcheck|integ)|--overwrite')

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

    def test_missing_plugin_registration_is_incomplete_despite_auto_approval(self):
        module = self.herdr_module()
        plugins = {'eco.ws-number': {'plugin_root': str(self.home / '.config/herdr/plugins/local/eco-ws-number')}}
        with mock.patch.object(module.Path, 'home', return_value=self.home), \
                mock.patch.object(module, 'installed', return_value=plugins), \
                mock.patch.object(module.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'did not register the expected revision'):
                module.bootstrap()
            self.assertEqual(run.call_args.args[0], ['herdr', 'plugin', 'install', module.PLUGINS[0][1], '--ref', module.PLUGINS[0][2], '--yes'])

    def test_all_pinned_plugins_are_auto_approved_and_verified(self):
        module = self.herdr_module()
        plugins = {'eco.ws-number': {'plugin_root': str(self.home / '.config/herdr/plugins/local/eco-ws-number')}}
        snapshots = [dict(plugins)]
        for plugin_id, repository, revision in module.PLUGINS:
            plugins[plugin_id] = {'source': {'resolved_commit': revision}}
            snapshots.append(dict(plugins))
        with mock.patch.object(module.Path, 'home', return_value=self.home), \
                mock.patch.object(module, 'installed', side_effect=snapshots) as installed, \
                mock.patch.object(module.subprocess, 'run') as run:
            module.bootstrap()
            self.assertEqual(installed.call_count, 1 + len(module.PLUGINS))
            self.assertEqual(run.call_args_list, [
                mock.call(['herdr', 'plugin', 'install', repository, '--ref', revision, '--yes'],
                          check=True, timeout=600)
                for _, repository, revision in module.PLUGINS
            ])

    def test_auto_approved_plugin_with_wrong_revision_is_rejected(self):
        module = self.herdr_module()
        local = {'eco.ws-number': {'plugin_root': str(self.home / '.config/herdr/plugins/local/eco-ws-number')}}
        wrong = {**local, module.PLUGINS[0][0]: {'source': {'resolved_commit': 'unexpected'}}}
        with mock.patch.object(module.Path, 'home', return_value=self.home), \
                mock.patch.object(module, 'installed', side_effect=[local, wrong]), \
                mock.patch.object(module.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'did not register the expected revision'):
                module.bootstrap()
            self.assertEqual(run.call_count, 1)

    def mock_user_setup(self, has_toolchain=True, component_exit=0, analyzer_exit=0):
        calls = self.root / 'user-calls'
        config = self.home / '.config/nvim'
        config.mkdir(parents=True)
        (config / 'lazy-lock.json').write_text('{}')
        ltex = self.home / '.local/share/nvim/mason/bin/ltex-ls-plus'
        ltex.parent.mkdir(parents=True)
        ltex.write_text('#!/bin/sh\nexit 0\n')
        ltex.chmod(0o755)
        mocks = f'''
          id() {{ printf '1000\\n'; }}
          mise() {{
            case $1 in env) printf ':\\n';; where) printf '/fake/java\\n';;
              *) printf 'mise:%s\\n' "$*" >> "{calls}";; esac
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
          nvim() {{ :; }}; timeout() {{ shift; "$@"; }}
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
        self.assertIn('mise:install --yes', calls.read_text())
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
        result = subprocess.run(['/bin/bash', str(path)],
                                env=env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('without sudo', result.stderr)
        self.assertFalse(calls.exists())
        result = subprocess.run(['/bin/bash', str(path), '--help'], env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('curl -fsSL', result.stdout)
        self.assertFalse(calls.exists())

    def test_remote_bootstrap_requires_terminal_before_network(self):
        path = self.root / 'standalone.sh'
        shutil.copy2(REPO / 'install.sh', path)
        bins = self.root / 'bin'
        bins.mkdir()
        (bins / 'id').write_text('#!/bin/sh\nprintf "1000\\n"\n')
        (bins / 'id').chmod(0o755)
        for command in ['git', 'sudo']:
            mock_command = bins / command
            mock_command.write_text('#!/bin/sh\nexit 91\n')
            mock_command.chmod(0o755)
        result = subprocess.run(['/bin/bash', str(path)],
                                env={**BASE_ENV, 'PATH': f'{bins}:/usr/bin:/bin'},
                                start_new_session=True, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('interactive terminal', result.stderr)

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
