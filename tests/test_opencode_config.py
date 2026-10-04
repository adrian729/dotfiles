"""Offline OpenCode regressions. Run with unittest discovery; no model calls."""
import json
import shutil
import subprocess
from pathlib import Path
from test_claude_config import Fixture, ROOT

PACKAGE = ROOT / 'opencode'
SCRIPTS = PACKAGE / '.local/scripts'


class OpenCodeConfig(Fixture):
    def run_script(self, name, *args, data='', cwd=None, timeout=10):
        return subprocess.run([str(SCRIPTS / name), *map(str, args)], input=data, text=True,
                              capture_output=True, cwd=cwd or self.home, env=self.env, timeout=timeout)

    def catalog(self, available=None, config=None):
        self.write('.local/config/opencode-models.json', config or {
            'free_models': ['opencode/a-free', 'opencode/b-free'],
            'relay': ['paid/model', 'opencode/b-free', 'opencode/a-free'],
            'agents': {'relay': ['paid/model', 'opencode/b-free'],
                       'task': ['opencode-go/a-free', 'opencode/a-free']},
        })
        self.fake('opencode', 'import sys\nassert sys.argv[1:] == ["models", "opencode"]\n'
                  + ('raise SystemExit(1)' if available is None else f'print({available!r})'))

    def test_exact_free_ids_and_deployed_catalog(self):
        self.catalog('opencode-go/a-free\nopencode/a-free\nopencode/b-free\nwarning: stray output')
        p = self.run_script('opencode-agent-models-probe')
        self.assertEqual(p.returncode, 0, p.stderr)
        state = json.loads((self.home / '.local/state/agents/opencode-agent-model-overrides.json').read_text())
        self.assertEqual(state['agent'], {'relay': {'model': 'opencode/b-free'}, 'task': {'model': 'opencode/a-free'}})
        p = self.run_script('opencode-llm-probe')
        self.assertEqual(p.returncode, 0, p.stderr)
        state = json.loads((self.home / '.local/state/agents/opencode-llm.json').read_text())
        self.assertEqual(state['models'], ['opencode/b-free', 'opencode/a-free'])

    def test_unavailable_catalog_cannot_unpin_agents_or_discover_unapproved_models(self):
        for available in (None, 'opencode-go/a-free\nopencode/unapproved-free'):
            self.catalog(available)
            p = self.run_script('opencode-agent-models-probe')
            self.assertNotEqual(p.returncode, 0)
            pins = json.loads((self.home / '.local/state/agents/opencode-agent-model-overrides.json').read_text())
            self.assertEqual(pins['agent']['task']['model'], 'opencode/a-free')
            self.assertNotIn('ambient', p.stderr)
            p = self.run_script('opencode-llm-probe')
            self.assertNotEqual(p.returncode, 0)
            state = json.loads((self.home / '.local/state/agents/opencode-llm.json').read_text())
            self.assertEqual(state['models'], [])

    def test_unconfigured_free_pin_rejected_without_overwriting_state(self):
        self.catalog('opencode/a-free', {'free_models': ['opencode/a-free'], 'relay': [],
                     'agents': {'task': ['opencode-go/a-free']}})
        old = self.write('.local/state/agents/opencode-agent-model-overrides.json', 'old pins')
        p = self.run_script('opencode-agent-models-probe')
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual(old.read_text(), 'old pins')

    def installer_fixture(self):
        package = self.home / 'installer/opencode'
        package.mkdir(parents=True)
        shutil.copy2(PACKAGE / 'install.sh', package / 'install.sh')
        for relative in ('.config/opencode/opencode.json', '.local/config/opencode-models.json'):
            self.write('installer/opencode/' + relative, (PACKAGE / relative).read_text())
        self.write('installer/lib/common.sh', '''
brew_shellenv() { :; }
ensure_cmd() { command -v "$1" >/dev/null; }
have() { command -v "$1" >/dev/null; }
warn() { echo "$*" >&2; }
run_remote_installer() { return 1; }
''')
        return package

    def install(self, package):
        return subprocess.run(['bash', str(package / 'install.sh')], env=self.env,
                              text=True, capture_output=True, timeout=5)

    def test_offline_install_has_free_pins_and_preserves_symlink_source(self):
        package = self.installer_fixture()
        old = self.write('tracked.json', '{"keep":true}')
        target = self.home / '.config/opencode/opencode.json'
        target.parent.mkdir(parents=True)
        target.symlink_to(old)
        # A stale override from a previous successful probe must not be merged.
        self.write('.local/state/agents/opencode-agent-model-overrides.json', {'agent': {'task': {'model': 'paid/model'}}})
        self.fake_probe('opencode-agent-models-probe', 'exit 1')
        p = self.install(package)
        self.assertEqual(p.returncode, 0, p.stderr)
        cfg = json.loads(target.read_text())
        free = json.loads((PACKAGE / '.local/config/opencode-models.json').read_text())['free_models']
        self.assertEqual(len(cfg['agent']), 10)
        self.assertTrue(all(agent['model'] in free for agent in cfg['agent'].values()))
        self.assertIn(cfg['small_model'], free)
        self.assertFalse(target.is_symlink())
        self.assertEqual(old.read_text(), '{"keep":true}')
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    def fake_probe(self, name, body):
        p = self.write('.local/scripts/' + name, '#!/bin/bash\n' + body + '\n')
        p.chmod(0o755)

    def test_install_merges_verified_pins(self):
        package = self.installer_fixture()
        free = json.loads((PACKAGE / '.local/config/opencode-models.json').read_text())
        pins = {'agent': {name: {'model': 'opencode/big-pickle'} for name in free['agents']}}
        self.write('.local/state/agents/opencode-agent-model-overrides.json', pins)
        self.fake_probe('opencode-agent-models-probe', 'exit 0')
        p = self.install(package)
        self.assertEqual(p.returncode, 0, p.stderr)
        cfg = json.loads((self.home / '.config/opencode/opencode.json').read_text())
        self.assertEqual(cfg['agent']['task']['model'], 'opencode/big-pickle')
        self.assertEqual(cfg['small_model'], 'opencode/big-pickle')
        self.assertEqual(cfg['agent']['relay']['permission'], {'*': 'deny'})

    def test_installer_leaves_existing_config_on_bad_source_or_folded_directory(self):
        package = self.installer_fixture()
        target = self.write('.config/opencode/opencode.json', 'existing config')
        source = package / '.config/opencode/opencode.json'
        original = source.read_text()
        source.write_text('{invalid')
        self.assertNotEqual(self.install(package).returncode, 0)
        self.assertEqual(target.read_text(), 'existing config')
        source.write_text(original)
        target.unlink()
        target.parent.rmdir()
        target.parent.symlink_to(package / '.config/opencode', target_is_directory=True)
        self.assertNotEqual(self.install(package).returncode, 0)
        self.assertEqual(source.read_text(), original)

    def test_ollama_failure_preserves_state_empty_success_clears_models(self):
        # Deploy the paired scripts to exercise the adjacent probe lookup.
        for name in ('opencode-ollama-models-probe', 'opencode-ollama-models-sync'):
            p = self.write('.local/scripts/' + name, (SCRIPTS / name).read_text())
            p.chmod(0o755)
        target = self.write('.config/opencode/opencode.json', {'provider': {'ollama': {'npm': 'existing', 'options': {'baseURL': 'http://fixture:11434/v1'}, 'models': {'old': {}}}}, 'other': True})
        state = self.write('.local/state/agents/opencode-ollama-models.json', {'old': {}})
        self.env.pop('OLLAMA_HOST', None)
        for response in (None, '{}', '{broken', '{"models":[{}]}'):
            self.fake('curl', 'raise SystemExit(7)' if response is None else f'print({response!r})')
            p = self.run_script('opencode-ollama-models-sync')
            self.assertNotEqual(p.returncode, 0)
            self.assertEqual(json.loads(state.read_text()), {'old': {}})
            self.assertIn('old', json.loads(target.read_text())['provider']['ollama']['models'])
        self.fake('curl', 'import sys\nassert sys.argv[-1] == "http://fixture:11434/api/tags"\nprint(\'{"models":[]}\')')
        p = self.run_script('opencode-ollama-models-sync')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(json.loads(target.read_text()), {'provider': {'ollama': {'npm': 'existing', 'options': {'baseURL': 'http://fixture:11434/v1'}, 'models': {}}}, 'other': True})
        self.env['OLLAMA_HOST'] = 'other:1234/'
        self.fake('curl', 'import sys\nassert sys.argv[-1] == "http://other:1234/api/tags"\nprint(\'{"models":[{"name":"fixture:3b"}]}\')')
        p = self.run_script('opencode-ollama-models-sync')
        self.assertEqual(p.returncode, 0, p.stderr)
        provider = json.loads(target.read_text())['provider']['ollama']
        self.assertEqual(provider['options']['baseURL'], 'http://other:1234/v1')
        self.assertIn('fixture:3b', provider['models'])

    def test_setup_preserves_zshrc_and_custom_scripts(self):
        for name in ('opencode', 'gh', 'tmux'):
            self.fake(name, 'raise SystemExit(0)')
        rc = self.write('tracked-zshrc', 'local config')
        (self.home / '.zshrc').symlink_to(rc)
        self.write('.local/scripts/opencode-wt', 'custom script')
        for _ in range(2):
            p = subprocess.run(['bash', str(PACKAGE / 'standalone_quick_setup.sh')], env=self.env,
                               input='', text=True, capture_output=True, timeout=5)
            self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(rc.read_text(), 'local config')
        self.assertEqual((self.home / '.local/.local_profile').read_text().count('# opencode-wt setup'), 1)
        backups = list(self.home.glob('.local/state/dotfiles/backups/*/opencode-wt'))
        self.assertEqual([p.read_text() for p in backups], ['custom script'])

    def test_pre_stow_backs_up_different_scripts(self):
        self.write('.local/scripts/opencode-wt', 'local changes')
        self.write('.local/scripts/opencode-git-wt', (SCRIPTS / 'opencode-git-wt').read_text())
        p = subprocess.run(['bash', str(PACKAGE / 'pre_stow.sh')], env=self.env, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse((self.home / '.local/scripts/opencode-git-wt').exists())
        self.assertEqual([p.read_text() for p in self.home.glob('.local/state/dotfiles/backups/*/opencode-wt')], ['local changes'])

    def test_worktree_names_session_json_and_failed_cli(self):
        repo = self.repo()
        for name, args in [('opencode-wt', ['-d', '../repo']), ('opencode-git-wt', ['../repo', 'status']),
                           ('opencode-open-wt', ['true', '../repo']), ('opencode-wt', ['@{-1}'])]:
            p = self.run_script(name, *args, cwd=repo)
            self.assertNotEqual(p.returncode, 0, (name, p.stdout, p.stderr))
        path = str(repo / '.worktrees/feature')
        self.fake('opencode', f'''import json, os, sys
from pathlib import Path
if sys.argv[1:3] == ['session', 'list']:
 print(json.dumps([{{'id': 'child', 'parentID': 'parent', 'directory': {path!r}}}, {{'id': 'parent', 'directory': {path!r}}}], separators=(',', ':')))
else:
 Path(os.environ['HOME'], 'cli-args').write_text(json.dumps(sys.argv[1:]))
 raise SystemExit(7)
''')
        p = self.run_script('opencode-wt', 'feature', cwd=repo)
        self.assertEqual(p.returncode, 7, p.stderr)
        self.assertEqual(self.git(repo, 'config', '--get', 'wt.feature.session'), 'parent')
        p = self.run_script('opencode-wt', 'feature', cwd=repo)
        self.assertEqual(p.returncode, 7)
        self.assertEqual(json.loads((self.home / 'cli-args').read_text()), ['--session', 'parent'])
        self.assertNotIn('Push and open', p.stdout)

    def test_plugin_failure_paths(self):
        node = shutil.which('node')
        if not node:
            self.skipTest('node not installed')
        self.catalog()
        p = subprocess.run([node, str(ROOT / 'tests/test_opencode_fallback.mjs')], env=self.env,
                           text=True, capture_output=True, timeout=10)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
