"""Offline Ollama regressions: never start services, download, or infer."""
import json
from pathlib import Path
import subprocess
import unittest
from test_claude_config import Fixture, ROOT

SCRIPTS = ROOT / 'ollama/.local/scripts'


class OllamaFixture(Fixture):
    def run_script(self, name, *args, data='', cwd=None, timeout=10):
        return subprocess.run([str(SCRIPTS / name), *args], input=data, text=True,
                              capture_output=True, cwd=cwd or self.home, env=self.env, timeout=timeout)


class PullModels(OllamaFixture):
    def setUp(self):
        super().setUp()
        self.env.pop('OLLAMA_HOST', None)
        self.write('.local/state/agents/local-llm.json', {'model_budget_gb': 8})
        self.catalog = self.write('.local/config/local-llm-models.json', {
            'models': {'small:1': {'footprint_gb': 6.5}, 'extra:1': {'footprint_gb': 7},
                       'big:1': {'footprint_gb': 8.5}},
            'pull_lineup': ['small:1', 'big:1'], 'pull_extras': ['extra:1', 'small:1']})
        self.fake('ollama', '''import os, sys
from pathlib import Path
home = Path(os.environ['HOME'])
args = sys.argv[1:]
with (home / 'calls').open('a') as f: f.write(' '.join(args) + '\\n')
if args == ['list']:
    if os.environ.get('OLLAMA_TEST_LIST_FAIL'): raise SystemExit(7)
    print('NAME ID SIZE MODIFIED')
    print(os.environ.get('OLLAMA_TEST_INSTALLED', ''))
elif args[0] == 'pull':
    if args[1] == os.environ.get('OLLAMA_TEST_PULL_FAIL'): raise SystemExit(9)
else: raise SystemExit('Unexpected Ollama invocation')
''')

    def calls(self):
        p = self.home / 'calls'
        return p.read_text().splitlines() if p.exists() else []

    def test_combined_flags_both_orders_and_decimal_budget(self):
        for args in (('--all', '--yes'), ('--yes', '--all')):
            with self.subTest(args=args):
                p = self.run_script('llm-models-pull', *args)
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertEqual(self.calls(), ['list', 'pull small:1', 'pull extra:1'])
                self.assertIn('skipping big:1', p.stdout)
                (self.home / 'calls').unlink()

    def test_later_unknown_flag_rejected_before_list(self):
        p = self.run_script('llm-models-pull', '--yes', '--typo')
        self.assertEqual(p.returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_empty_lineup_means_no_downloads(self):
        self.catalog.write_text('{"pull_lineup": [], "pull_extras": []}')
        p = self.run_script('llm-models-pull', '--all', '--yes')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.calls(), ['list'])

    def test_missing_catalog_still_enforces_memory_budget(self):
        self.catalog.unlink()
        p = self.run_script('llm-models-pull', '--all', '--yes')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(sorted(self.calls()), ['list', 'pull qwen2.5-coder:7b', 'pull qwen3:8b'])

    def test_invalid_catalog_never_downloads(self):
        for data in ('{', '', '{} {}', '{"pull_lineup":null}', '{"pull_lineup":["unknown"]}',
                     '{"models":{"small:1":{"footprint_gb":-1}},"pull_lineup":["small:1"]}'):
            self.catalog.write_text(data)
            p = self.run_script('llm-models-pull', '--yes')
            self.assertNotEqual(p.returncode, 0, data)
            self.assertEqual(self.calls(), [])

    @unittest.skipUnless(Path('/proc/meminfo').is_file(), 'reads the real /proc/meminfo')
    def test_linux_memory_fallback_survives_broken_nvidia(self):
        (self.home / '.local/state/agents/local-llm.json').unlink()
        self.fake('uname', 'print("Linux")')
        self.fake('nvidia-smi', 'raise SystemExit(1)')
        self.fake('sysctl', 'raise SystemExit("Linux should not call sysctl")')
        p = self.run_script('llm-models-pull', '--yes')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn('sysctl', p.stderr)

    def test_noop_refreshes_each_available_probe(self):
        self.env['OLLAMA_TEST_INSTALLED'] = 'small:1 hash 1GB now'
        self.fake('llm-probe', 'from pathlib import Path; import os; (Path(os.environ["HOME"]) / "refreshed").touch()')
        p = self.run_script('llm-models-pull', '--yes')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.calls(), ['list'])
        self.assertTrue((self.home / 'refreshed').exists())

    def test_list_and_pull_failures_propagate(self):
        self.env['OLLAMA_TEST_LIST_FAIL'] = '1'
        p = self.run_script('llm-models-pull', '--yes')
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual(self.calls(), ['list'])
        self.env.pop('OLLAMA_TEST_LIST_FAIL')
        self.env['OLLAMA_TEST_PULL_FAIL'] = 'small:1'
        p = self.run_script('llm-models-pull', '--yes')
        self.assertNotEqual(p.returncode, 0)

    def test_no_confirmation_means_no_pull(self):
        p = self.run_script('llm-models-pull')
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual(self.calls(), ['list'])

    def test_names_match_literally_and_default_tag_is_recognized(self):
        self.catalog.write_text(json.dumps({'models': {'test.a': {'footprint_gb': 1}},
                                           'pull_lineup': ['test.a']}))
        self.env['OLLAMA_TEST_INSTALLED'] = 'testXa:latest hash 1GB now'
        p = self.run_script('llm-models-pull', '--yes')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('pull test.a', self.calls())
        (self.home / 'calls').unlink()
        self.env['OLLAMA_TEST_INSTALLED'] = 'test.a:latest hash 1GB now'
        p = self.run_script('llm-models-pull', '--yes')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.calls(), ['list'])


class ServiceControl(OllamaFixture):
    def setUp(self):
        super().setUp()
        self.fake('uname', 'import os; print(os.environ.get("OLLAMA_TEST_OS", "Linux"))')
        self.fake('id', 'print(0)')
        self.fake('ps', 'print(1024)')
        self.fake('curl', 'print(\'{"models":[]}\')')
        self.fake('sudo', 'raise SystemExit("Unexpected sudo")')
        self.fake('systemctl', '''import os, sys
from pathlib import Path
args = sys.argv[1:]
with (Path(os.environ['HOME']) / 'service-calls').open('a') as f: f.write(' '.join(args) + '\\n')
if '--property=LoadState' in args:
    print('loaded' if ('--user' not in args or os.environ.get('OLLAMA_TEST_USER_UNIT')) else 'not-found')
elif '--property=ActiveState' in args:
    if os.environ.get('OLLAMA_TEST_STATUS_FAIL'): raise SystemExit(1)
    print('active')
elif '--property=MainPID' in args: print(321)
elif any(x in args for x in ('start', 'stop', 'restart')):
    raise SystemExit(int(os.environ.get('OLLAMA_TEST_CHANGE_EXIT', 0)))
else: raise SystemExit('Unexpected systemctl call')
''')

    def test_empty_model_list_is_successful_status(self):
        p = self.run_script('ollama-ctl')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('PID: 321', p.stdout)

    def test_change_errors_propagate_and_restart_is_native(self):
        self.env['OLLAMA_TEST_CHANGE_EXIT'] = '7'
        for action in ('start', 'stop', 'restart'):
            p = self.run_script('ollama-ctl', action)
            self.assertEqual(p.returncode, 7, p.stderr)
            self.assertNotIn('running', p.stdout)
        calls = (self.home / 'service-calls').read_text()
        self.assertIn('restart ollama.service', calls)

    def test_user_service_needs_no_sudo(self):
        self.env['OLLAMA_TEST_USER_UNIT'] = '1'
        self.fake('id', 'print(1000)')
        p = self.run_script('ollama-ctl', 'start')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('--user start ollama.service', (self.home / 'service-calls').read_text())

    def test_status_errors_do_not_claim_stopped(self):
        self.env['OLLAMA_TEST_STATUS_FAIL'] = '1'
        p = self.run_script('ollama-ctl')
        self.assertNotEqual(p.returncode, 0)
        self.assertNotIn('stopped', p.stdout)

    def test_help_never_probes_services_and_extra_args_rejected(self):
        p = self.run_script('ollama-ctl', '--help')
        self.assertEqual(p.returncode, 0)
        self.assertFalse((self.home / 'service-calls').exists())
        self.assertEqual(self.run_script('ollama-ctl', 'start', 'oops').returncode, 2)

    def test_brew_status_and_command_failures(self):
        self.env['OLLAMA_TEST_OS'] = 'Darwin'
        self.fake('brew', '''import os, sys
if sys.argv[1:3] == ['services', 'info']:
    print('[{"name":"ollama","running":true,"pid":456,"status":"started"}]')
elif sys.argv[1:2] == ['list']: pass
else: raise SystemExit(int(os.environ.get('OLLAMA_TEST_CHANGE_EXIT', 0)))
''')
        p = self.run_script('ollama-ctl')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('PID: 456', p.stdout)
        self.env['OLLAMA_TEST_CHANGE_EXIT'] = '8'
        self.assertEqual(self.run_script('ollama-ctl', 'restart').returncode, 8)

    QUIT = 'osascript -e with timeout of 5 seconds -e quit app "Ollama" -e end timeout'

    def app_fixture(self, brew=True, app=True, running=True, osascript_rc=0):
        self.env['OLLAMA_TEST_OS'] = 'Darwin'
        self.env['OLLAMA_CTL_WAIT_TRIES'] = '1'
        self.env['OLLAMA_CTL_APPS_DIR'] = str(self.home / 'no-system-apps')
        if app:
            (self.home / 'Applications/Ollama.app').mkdir(parents=True)
        if brew:
            self.fake('brew', 'raise SystemExit(1)')
        log = 'import os, sys\nfrom pathlib import Path\n' \
              "Path(os.environ['HOME'], 'app-calls').open('a').write('%s ' + ' '.join(sys.argv[1:]) + '\\n')\n"
        self.fake('open', log % 'open')
        self.fake('osascript', log % 'osascript' + f'raise SystemExit({osascript_rc})\n')
        self.fake('pkill', log % 'pkill')
        # A real regex match over a process list that always holds a decoy.
        procs = [(999, 'vim notes-ollama serve.md')]
        if running:
            procs.append((654, '/Applications/Ollama.app/Contents/Resources/ollama serve'))
        self.fake('pgrep', f'import re, sys\nhits = [p for p, c in {procs!r} if re.search(sys.argv[-1], c)]\n'
                           'print(*hits, sep="\\n") if hits else sys.exit(1)\n')

    def app_calls(self):
        return (self.home / 'app-calls').read_text().splitlines()

    def test_app_mode_status_start_stop_restart(self):
        self.app_fixture()
        p = self.run_script('ollama-ctl')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('ollama: running', p.stdout)
        self.assertIn('PID: 654', p.stdout)
        self.assertEqual(self.run_script('ollama-ctl', 'start').returncode, 0)
        self.assertEqual(self.app_calls(), ['open -g -a Ollama'])
        self.assertEqual(self.run_script('ollama-ctl', 'stop').returncode, 0)
        self.assertEqual(self.app_calls()[-1], self.QUIT)
        self.assertEqual(self.run_script('ollama-ctl', 'restart').returncode, 0)
        self.assertEqual(self.app_calls()[-2:], [self.QUIT, 'open -g -a Ollama'])

    def test_app_mode_stop_falls_back_to_sigterm(self):
        self.app_fixture(osascript_rc=1)
        self.assertEqual(self.run_script('ollama-ctl', 'stop').returncode, 0)
        self.assertEqual(self.app_calls(), [self.QUIT, 'pkill -TERM -x Ollama'])

    def test_app_mode_without_brew_and_stopped_status(self):
        self.app_fixture(brew=False, running=False)
        self.fake('curl', 'raise SystemExit(7)')
        p = self.run_script('ollama-ctl')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('ollama: stopped', p.stdout)

    def test_no_install_found_fails(self):
        self.app_fixture(app=False)
        p = self.run_script('ollama-ctl', 'start')
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('no Ollama install found', p.stderr)
        self.assertFalse((self.home / 'app-calls').exists())


class TmuxAndEnv(OllamaFixture):
    def test_memory_counts_only_daemon_and_descendants(self):
        self.fake('ps', '''print("""10 1 1024 /usr/local/bin/ollama serve
11 10 1048576 /usr/local/bin/ollama runner --model fixture
12 11 1024 llama-server
20 1 2097152 llama-server
21 1 2097152 /usr/local/bin/ollama list""")''')
        self.fake('curl', 'print(\'{"models":[]}\')')
        p = subprocess.run([str(ROOT / 'tmux/.local/scripts/tmux-ollama-status')],
                           env=self.env, text=True, capture_output=True, timeout=3)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('id10', p.stdout)
        self.assertIn('1.0GiB', p.stdout)
        self.assertEqual(p.stderr, '')

    def test_blank_env_template_preserves_inherited_key(self):
        self.env['OLLAMA_API_KEY'] = 'fixture-key'
        template = ROOT / 'ollama/.config/ollama/ollama.env.template'
        p = subprocess.run(['bash', '-c', '. "$1"; printf "%s" "$OLLAMA_API_KEY"', 'fixture', str(template)],
                           env=self.env, text=True, capture_output=True)
        self.assertEqual(p.stdout, 'fixture-key')


class Installation(OllamaFixture):
    def setUp(self):
        super().setUp()
        self.installer = self.write('installer/ollama/install.sh', (ROOT / 'ollama/install.sh').read_text())
        self.write('installer/lib/common.sh', '''
brew_shellenv() { :; }
have() { [ "${OLLAMA_TEST_INSTALLED:-}" = 1 ]; }
is_macos() { return 1; }
is_linux() { return 0; }
ensure_cmd() { [ "${OLLAMA_TEST_DEPENDENCY_FAIL:-}" != "$1" ]; }
run_remote_installer() { return "${OLLAMA_TEST_INSTALL_EXIT:-0}"; }
info() { echo "$*"; }
warn() { echo "$*" >&2; }
''')

    def install(self):
        return subprocess.run(['bash', str(self.installer)], env=self.env,
                              text=True, capture_output=True, timeout=3)

    def test_installer_and_dependency_failures_propagate(self):
        self.env['OLLAMA_TEST_INSTALL_EXIT'] = '7'
        p = self.install()
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('install failed', p.stderr)
        self.env['OLLAMA_TEST_INSTALLED'] = '1'
        self.env['OLLAMA_TEST_DEPENDENCY_FAIL'] = 'jq'
        self.assertNotEqual(self.install().returncode, 0)

    def test_env_is_optional_and_existing_local_files_are_preserved(self):
        self.env['OLLAMA_TEST_INSTALLED'] = '1'
        p = self.install()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('Optional', p.stdout)
        local_env = self.write('.config/ollama/ollama.env', '# local settings\n')
        local_rc = self.write('.zshrc', '# local shell\n')
        p = self.install()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(local_env.read_text(), '# local settings\n')
        self.assertEqual(local_rc.read_text(), '# local shell\n')
