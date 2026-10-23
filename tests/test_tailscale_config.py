"""Offline Tailscale install and privacy regressions; no real services touched."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

from test_claude_config import Fixture, ROOT

PACKAGE = ROOT / 'tailscale'
STOW = shutil.which('stow')


class TailscaleFixture(Fixture):
    def setUp(self):
        super().setUp()
        self.farm = self.home / 'farm'
        shutil.copytree(PACKAGE, self.farm / 'tailscale')
        self.write('farm/lib/common.sh', '''
brew_shellenv() { :; }
is_linux() { [ "${TEST_OS:-Linux}" = Linux ]; }
is_macos() { [ "${TEST_OS:-Linux}" = Darwin ]; }
have() {
    [ "$1" != "${TEST_MISSING:-}" ] || return 1
    case "$1" in
    tailscale) [ "${TEST_CLIENT:-}" = cli ] ;;
    tailscaled) [ "${TEST_CLIENT:-}" = daemon ] ;;
    *) command -v "$1" >/dev/null ;;
    esac
}
ensure_cmd() { echo "dependency:$*" >> "$HOME/calls"; }
ensure_cask() {
    [ -d "$HOME/Applications/$2" ] && return 0
    echo "cask:$*" >> "$HOME/calls"
    return "${TEST_INSTALL_EXIT:-0}"
}
run_remote_installer() {
    echo "remote:$*" >> "$HOME/calls"
    return "${TEST_INSTALL_EXIT:-0}"
}
info() { echo "$*"; }
warn() { echo "$*" >&2; }
''')
        # Any accidental login, status probe or service mutation must fail.
        for tool in ('tailscale', 'tailscaled', 'sudo', 'systemctl', 'launchctl', 'open'):
            self.fake(tool, 'raise SystemExit("Unexpected external action")')

    def run_command(self, *args):
        return subprocess.run(list(map(str, args)), env=self.env, cwd=self.farm,
                              text=True, capture_output=True, timeout=10)

    def install(self):
        return self.run_command('bash', self.farm / 'tailscale/install.sh')

    def calls(self):
        path = self.home / 'calls'
        return path.read_text() if path.exists() else ''

    def hosts(self):
        return Path(self.env['XDG_CONFIG_HOME']) / 'tssh/hosts.json'


class Installation(TailscaleFixture):
    def test_new_linux_and_mac_use_their_native_installers(self):
        for platform, expected in (
                ('Linux', 'remote:https://tailscale.com/install.sh'),
                ('Darwin', 'cask:tailscale-app Tailscale.app')):
            with self.subTest(platform=platform):
                self.env['TEST_OS'] = platform
                p = self.install()
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertIn(expected, self.calls())
                self.assertEqual(self.hosts().read_text(), '{}\n')
                self.assertEqual(self.hosts().stat().st_mode & 0o777, 0o600)
                (self.home / 'calls').unlink()

    def test_existing_clients_preserve_private_files_across_reinstalls(self):
        for platform in ('Linux', 'Darwin'):
            for client in ('cli', 'daemon'):
                with self.subTest(platform=platform, client=client):
                    self.env.update(TEST_OS=platform, TEST_CLIENT=client)
                    files = [self.write('.config/tssh/hosts.json', '{"private": {"address": "local-only"}}'),
                             self.write('.ssh/config', '# existing SSH config\n'),
                             self.write('.ssh/known_hosts', 'existing host key\n'),
                             self.write('.local/.local_profile', '# existing shell config\n')]
                    before = [(p.read_bytes(), p.stat().st_mode, p.stat().st_mtime_ns) for p in files]
                    for _ in range(2):
                        p = self.install()
                        self.assertEqual(p.returncode, 0, p.stderr)
                    self.assertEqual(before, [(p.read_bytes(), p.stat().st_mode, p.stat().st_mtime_ns) for p in files])
                    self.assertNotIn('remote:', self.calls())
                    self.assertNotIn('cask:', self.calls())

    def test_existing_macos_app_without_cli_is_not_replaced(self):
        self.env['TEST_OS'] = 'Darwin'
        (self.home / 'Applications/Tailscale.app').mkdir(parents=True)
        self.assertEqual(self.install().returncode, 0)
        self.assertNotIn('cask:', self.calls())

    def test_failures_propagate(self):
        self.env['TEST_INSTALL_EXIT'] = '9'
        for platform in ('Linux', 'Darwin'):
            self.env['TEST_OS'] = platform
            self.assertNotEqual(self.install().returncode, 0)

    def test_missing_prerequisites_fail_before_installing(self):
        for tool in ('python3', 'ssh'):
            self.env['TEST_MISSING'] = tool
            self.assertNotEqual(self.install().returncode, 0)
            self.assertFalse((self.home / 'calls').exists())

    def test_custom_xdg_and_dangling_symlink_are_preserved(self):
        self.env.update(TEST_CLIENT='cli', XDG_CONFIG_HOME=str(self.home / 'custom config'))
        self.hosts().parent.mkdir(parents=True)
        target = self.home / 'not-present'
        self.hosts().symlink_to(target)
        self.assertEqual(self.install().returncode, 0)
        self.assertEqual(self.hosts().readlink(), target)
        self.assertFalse(target.exists())

    @unittest.skipUnless(STOW, 'GNU Stow required')
    def test_real_restow_preserves_private_data_and_excludes_metadata(self):
        self.env['TEST_CLIENT'] = 'cli'
        # Even a private file accidentally placed inside the package must not deploy.
        self.write('farm/tailscale/.config/tssh/hosts.json', '{"do-not-deploy": {}}')
        self.assertEqual(self.install().returncode, 0)
        self.hosts().write_text('{"private-local-host": {}}\n')
        for _ in range(2):
            p = self.run_command(STOW, '--no-folding', '-R', '-d', self.farm,
                                 '-t', self.home, 'tailscale')
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertEqual(self.install().returncode, 0)
            self.assertEqual(self.hosts().read_text(), '{"private-local-host": {}}\n')
            self.assertFalse(self.hosts().is_symlink())
            self.assertTrue((self.home / '.local/scripts/tssh').is_symlink())
            self.assertFalse((self.home / '.config').is_symlink())
        for name in ('install.sh', 'README.md', '.gitignore'):
            self.assertFalse((self.home / name).exists(), name)

    def test_private_host_file_is_gitignored(self):
        p = self.run_command('git', '-C', ROOT, 'check-ignore',
                             'tailscale/.config/tssh/hosts.json')
        self.assertEqual(p.returncode, 0, p.stderr)


class HostPicker(TailscaleFixture):
    def setUp(self):
        super().setUp()
        self.write('.config/tssh/hosts.json', {
            'test-host': {'address': 'test.example-tailnet.ts.net', 'ssh_host': 'existing-alias',
                          'host_key_alias': 'existing-host', 'user': 'fixture', 'port': 2222,
                          'identity_file': '~/.ssh/test key'}})
        self.fake('ssh', '''import json, sys
print(json.dumps(sys.argv[1:]))
raise SystemExit(7)
''')

    def tssh(self, *args):
        return self.run_command(PACKAGE / '.local/scripts/tssh', *args)

    def test_ssh_uses_private_config_and_preserves_arguments_and_exit_status(self):
        p = self.tssh('test-host', 'printf', '%s', 'two words')
        self.assertEqual(p.returncode, 7, p.stderr)
        args = json.loads(p.stdout)
        self.assertIn('Hostname=test.example-tailnet.ts.net', args)
        self.assertIn('HostKeyAlias=existing-host', args)
        self.assertIn('User=fixture', args)
        self.assertIn('Port=2222', args)
        self.assertIn(str(self.home / '.ssh/test key'), args)
        self.assertEqual(args[-5:], ['--', 'existing-alias', 'printf', '%s', 'two words'])

    def test_flags_and_unknown_host(self):
        for flag in ('-h', '--help'):
            p = self.tssh(flag)
            self.assertEqual(p.returncode, 0)
            self.assertIn('-l, --list', p.stdout)
        for flag in ('-l', '--list'):
            p = self.tssh(flag)
            self.assertEqual(p.returncode, 0)
            self.assertIn('test-host', p.stdout)
        for flag in ('-n', '--dry-run'):
            p = self.tssh(flag, 'test-host')
            self.assertEqual(p.returncode, 0)
            self.assertIn('ssh -o', p.stdout)
        self.assertNotEqual(self.tssh('missing').returncode, 0)

    def test_empty_config_explains_setup_and_help_works_without_config(self):
        self.hosts().write_text('{}\n')
        self.assertIn('no hosts configured', self.tssh('-l').stderr)
        self.hosts().unlink()
        self.assertEqual(self.tssh('-h').returncode, 0)
