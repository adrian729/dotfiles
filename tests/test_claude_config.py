"""Offline regressions for Claude's shell/ACP integration.
Run: python3 -m unittest discover -s tests -v
All tools that can invoke models or network services are replaced by fixtures.
"""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLAUDE = ROOT / 'claude'
SCRIPTS = CLAUDE / '.local/scripts'


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        # Resolve symlinked temp roots (macOS /var -> /private/var) so paths
        # the scripts print through getcwd() or realpath match the fixture.
        self.home = Path(self.tmp.name).resolve()
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = {**os.environ, 'HOME': str(self.home), 'PATH': f'{self.bin}:/usr/bin:/bin',
                    'XDG_CONFIG_HOME': str(self.home / '.config'),
                    'XDG_CACHE_HOME': str(self.home / '.cache'), 'TMPDIR': str(self.home),
                    'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'}
        for key in ('TMUX', 'CLAUDE_CONFIG_DIR', 'GIT_DIR', 'GIT_WORK_TREE', 'BASH_ENV'):
            self.env.pop(key, None)
        self.fake('curl', 'raise SystemExit("Unexpected network request")')
        self.fake('security', 'raise SystemExit(1)')
        self.fake('claude', 'raise SystemExit("Unexpected model request")')
        self.fake('opencode', 'raise SystemExit("Unexpected model request")')

    def fake(self, name, source):
        p = self.bin / name
        p.write_text(f'#!{sys.executable}\n' + source + '\n')
        p.chmod(0o755)
        return p

    def write(self, relative, data):
        p = self.home / relative
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(data) if not isinstance(data, str) else data)
        return p

    def run_script(self, name, *args, data='', cwd=None, timeout=10):
        return subprocess.run([str(SCRIPTS / name), *map(str, args)], input=data, text=True,
                              capture_output=True, cwd=cwd or self.home, env=self.env, timeout=timeout)

    def git(self, repo, *args):
        return subprocess.run(['git', '-C', str(repo), *args], env=self.env, check=True,
                              text=True, capture_output=True).stdout.strip()

    def repo(self):
        p = self.home / 'repo'
        p.mkdir()
        self.git(p, 'init', '-b', 'fixture-main')
        self.git(p, 'config', 'user.name', 'Fixture')
        self.git(p, 'config', 'user.email', 'fixture@example.invalid')
        (p / 'file').write_text('initial\n')
        self.git(p, 'add', 'file')
        self.git(p, 'commit', '-m', 'initial')
        return p


class HooksAndSetup(Fixture):
    def test_legacy_hooks_neither_steer_nor_block_old_installs(self):
        payload = {'cwd': str(self.home),
                   'tool_input': {'subagent_type': 'implementer', 'model': 'haiku'}}
        for name in ('agent-skill-nudge', 'agent-eval', 'skill-eval', 'agent-guard'):
            p = subprocess.run([str(CLAUDE / f'.claude/hooks/{name}.sh')], env=self.env,
                               input=json.dumps(payload), text=True, capture_output=True, timeout=3)
            self.assertEqual((p.returncode, p.stdout, p.stderr), (0, '', ''), name)

    def test_pre_stow_preserves_different_scripts(self):
        target = self.write('.local/scripts/claude-wt', 'local edits\n')
        self.write('.local/scripts/git-wt', (SCRIPTS / 'git-wt').read_text())
        p = subprocess.run(['bash', str(CLAUDE / 'pre_stow.sh')], env=self.env, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse(target.exists())
        self.assertFalse((target.parent / 'git-wt').exists())
        backups = list(self.home.glob('.local/state/dotfiles/backups/*/claude-wt'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'local edits\n')

    def test_standalone_keeps_shell_config_and_local_scripts(self):
        for tool in ('claude', 'gh', 'tmux'):
            self.fake(tool, 'raise SystemExit(0)')
        rc = self.write('tracked-zshrc', 'precious config\n')
        (self.home / '.zshrc').symlink_to(rc)
        self.write('.local/scripts/claude-wt', 'custom script\n')
        for _ in range(2):
            p = subprocess.run(['bash', str(CLAUDE / 'standalone_quick_setup.sh')], env=self.env,
                               input='', text=True, capture_output=True, timeout=5)
            self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(rc.read_text(), 'precious config\n')
        self.assertEqual((self.home / '.local/.local_profile').read_text().count('# claude-wt setup'), 1)
        self.assertEqual(len(list(self.home.glob('.local/state/dotfiles/backups/*/claude-wt'))), 1)

    def test_installer_preserves_invalid_state_and_replaces_settings_symlink(self):
        package = self.home / 'installer/claude'
        package.mkdir(parents=True)
        (package / 'marketplace').mkdir()
        shutil.copy2(CLAUDE / 'install.sh', package / 'install.sh')
        self.write('installer/lib/common.sh', '''
brew_shellenv() { :; }
ensure_cmd() { command -v "$1" >/dev/null; }
have() { command -v "$1" >/dev/null; }
is_macos() { return 1; }
warn() { echo "$*" >&2; }
run_remote_installer() { echo "unexpected installation" >&2; return 1; }
''')
        self.fake('claude', 'raise SystemExit(0)')
        self.fake('claude-agent-acp', 'raise SystemExit(0)')
        state = self.write('.claude.json', '{broken')
        original = self.write('tracked-settings.json', '{"local":true}\n')
        target = self.home / '.claude/settings.json'
        target.parent.mkdir()
        target.symlink_to(original)
        # Missing source: the copy must not truncate existing settings.
        p = subprocess.run(['bash', str(package / 'install.sh')], env=self.env,
                           text=True, capture_output=True, timeout=5)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('failed to copy settings.json', p.stderr)
        self.assertEqual(state.read_text(), '{broken')
        self.assertTrue(target.is_symlink())
        self.write('installer/claude/.claude/settings.json', {'portable': True})
        state.write_text('{"local":"keep"}')
        p = subprocess.run(['bash', str(package / 'install.sh')], env=self.env,
                           text=True, capture_output=True, timeout=5)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(json.loads(state.read_text()), {'local': 'keep', 'editorMode': 'vim'})
        self.assertEqual(state.stat().st_mode & 0o777, 0o600)
        self.assertFalse(target.is_symlink())
        self.assertEqual(json.loads(target.read_text()), {'portable': True})
        self.assertEqual(original.read_text(), '{"local":true}\n')
        # A reinstall resets repo-managed keys but keeps the /model choice.
        target.write_text(json.dumps({'portable': False, 'hooks': {'old': 1}, 'model': 'opus',
                                      'modelSettings': {'claude-opus-5-5': {'effortLevel': 'xhigh'}}}))
        p = subprocess.run(['bash', str(package / 'install.sh')], env=self.env,
                           text=True, capture_output=True, timeout=5)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(json.loads(target.read_text()), {
            'portable': True, 'model': 'opus',
            'modelSettings': {'claude-opus-5-5': {'effortLevel': 'xhigh'}}})

    def test_worktree_names_and_failed_claude_exit(self):
        repo = self.repo()
        for name, args in [('claude-wt', ['-d', '../repo']), ('git-wt', ['../repo', 'status']),
                           ('open-wt', ['true', '../repo'])]:
            p = self.run_script(name, *args, cwd=repo)
            self.assertNotEqual(p.returncode, 0)
        self.fake('claude', 'raise SystemExit(7)')
        p = self.run_script('claude-wt', 'work', cwd=repo)
        self.assertEqual(p.returncode, 7, p.stderr)
        self.assertNotIn('Push', p.stdout)
        self.git(repo, 'config', 'wt.work.session', 'old-session')
        self.fake('gh', 'raise SystemExit(1)')
        p = self.run_script('claude-wt', '-d', 'work', cwd=repo)
        self.assertEqual(p.returncode, 0, p.stderr)
        config = self.git(repo, 'config', '--list')
        self.assertNotIn('old-session', config)


class LocalModels(Fixture):
    def setUp(self):
        super().setUp()
        self.write('.local/state/agents/local-llm.json', {'enabled': True, 'num_ctx': 8192,
                   'compress_models': ['fixture:3b'], 'code_models': ['fixture:3b']})
        self.fake('curl', '''import json, os, pathlib, sys
args = sys.argv[1:]
if any('/api/version' in a for a in args):
    print('{"version":"fixture"}'); sys.exit(0)
if any('/api/tags' in a for a in args):
    print(os.environ.get('TAGS', '{"models":[]}')); sys.exit(0)
pathlib.Path(args[args.index('-o')+1]).write_text(os.environ['RESPONSE'])
print('200', end='')
''')

    def test_incomplete_response_never_replaces_output(self):
        out = self.write('answer', 'keep me')
        for response in ({}, {'response': 'partial', 'done': False},
                         {'response': 'partial', 'done': True, 'done_reason': 'length'},
                         {'response': '', 'done': True}, 'invalid json'):
            self.env['RESPONSE'] = response if isinstance(response, str) else json.dumps(response)
            p = self.run_script('llm', '-o', out, 'summarize')
            self.assertEqual(p.returncode, 6, p.stderr)
            self.assertEqual(out.read_text(), 'keep me')
        self.env['RESPONSE'] = json.dumps({'response': 'answer', 'done': True, 'done_reason': 'stop'})
        p = self.run_script('llm', '-o', out, 'summarize')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(out.read_text(), 'answer\n')

    def test_model_discovery_preserves_tag_and_empty_server(self):
        self.env['TAGS'] = json.dumps({'models': [{'name': 'fixture:3b'}, {'name': 'fixture:1.5b'}]})
        p = self.run_script('llm-models-probe')
        self.assertEqual(p.returncode, 0, p.stderr)
        state = self.home / '.local/state/agents/local-llm-models.json'
        found = json.loads(state.read_text())
        self.assertEqual(found['compress_order'], ['fixture:3b', 'fixture:1.5b'])
        self.assertEqual(found['models']['fixture:3b']['footprint_gb'], 4)
        self.env['TAGS'] = '{"models":[]}'
        p = self.run_script('llm-models-probe')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(json.loads(state.read_text())['compress_order'], [])

    def test_catalog_success_and_builtin_capability_fallback(self):
        catalog = json.loads((CLAUDE / '.local/config/local-llm-models.json').read_text())
        self.write('.local/config/local-llm-models.json', catalog)
        self.env['TAGS'] = json.dumps({'models': [{'name': m} for m in catalog['models']]})
        p = self.run_script('llm-models-probe')
        self.assertEqual(p.returncode, 0, p.stderr)
        (self.home / '.local/state/agents/local-llm-models.json').unlink()
        (self.home / '.local/config/local-llm-models.json').unlink()
        self.fake('ollama', 'print("ollama version is 0.fixture")')
        self.env.update(LLM_PROBE_RAM_GB='32', LLM_PROBE_VRAM_GB='24')
        p = self.run_script('llm-probe')
        self.assertEqual(p.returncode, 0, p.stderr)
        state = json.loads((self.home / '.local/state/agents/local-llm.json').read_text())
        self.assertTrue(state['enabled'])
        self.assertEqual(state['compress_models'][0], 'gemma4:26b')


class OpenCode(Fixture):
    def setUp(self):
        super().setUp()
        self.write('.config/opencode/opencode-models.json', {'free_models': ['opencode/free-fixture'],
                   'relay': ['paid/fixture', 'opencode/free-fixture'],
                   'agents': {'task': ['paid/fixture', 'opencode/free-fixture']}})
        self.write('.local/state/agents/opencode-llm.json', {'models': ['paid/fixture', 'opencode/free-fixture']})
        self.env['CALL_LOG'] = str(self.home / 'calls')
        self.fake('opencode', '''import json, os, pathlib, signal, subprocess, sys, time
args = sys.argv[1:]
if args[:2] == ['agent', 'list']:
    print('task (primary)'); sys.exit(0)
if args[:2] == ['models', 'opencode']:
    print('opencode/free-fixture'); sys.exit(0)
assert os.environ.get('DOTFILES_OPENCODE_NO_FALLBACK') == '1'
with open(os.environ['CALL_LOG'], 'a') as f: f.write(json.dumps(args)+'\\n')
print(json.dumps({'type':'text','sessionID':'session-fixture','part':{'id':'part1','text':'answer'}}), flush=True)
mode = os.environ.get('OC_MODE')
if mode == 'timeout':
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    print('{', end='', flush=True); time.sleep(30)
if mode == 'malformed': print('{'); sys.exit(0)
if mode == 'unfinished': sys.exit(0)
if mode == 'commit':
    cwd = args[args.index('--dir')+1]
    pathlib.Path(cwd, 'file').write_text('updated\\n')
    subprocess.run(['git', '-C', cwd, 'commit', '-am', 'agent-change'], check=True, stdout=subprocess.DEVNULL)
print(json.dumps({'type':'step_finish','sessionID':'session-fixture','part':{'reason':'length' if mode == 'length' else 'stop'}}))
''')

    def test_default_walk_excludes_paid_and_explicit_model_is_honored(self):
        p = self.run_script('opencode-llm', 'summarize')
        self.assertEqual(p.returncode, 0, p.stderr)
        calls = (self.home / 'calls').read_text()
        self.assertIn('opencode/free-fixture', calls)
        self.assertNotIn('paid/fixture', calls)
        p = self.run_script('opencode-llm', '-m', 'paid/fixture', 'summarize')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('paid/fixture', (self.home / 'calls').read_text())

    def test_malformed_json_preserves_output(self):
        self.env['OC_MODE'] = 'malformed'
        out = self.write('answer', 'keep')
        p = self.run_script('opencode-llm', '-m', 'fixture', '-o', out, 'summarize')
        self.assertEqual(p.returncode, 6, p.stderr)
        self.assertEqual(out.read_text(), 'keep')

    def test_partial_responses_are_not_successful(self):
        repo = self.repo()
        out = self.write('answer', 'keep')
        for mode in ('unfinished', 'length'):
            self.env['OC_MODE'] = mode
            p = self.run_script('opencode-llm', '-m', 'fixture', '-o', out, 'summarize')
            self.assertEqual(p.returncode, 6, p.stderr)
            self.assertEqual(out.read_text(), 'keep')
            p = self.run_script('opencode-task', 'work', '-m', 'fixture', 'fix it', cwd=repo)
            self.assertEqual(p.returncode, 6, p.stderr)

    def test_deployed_catalog_fallback(self):
        catalog = self.home / '.config/opencode/opencode-models.json'
        self.write('.local/config/opencode-models.json', catalog.read_text())
        catalog.unlink()
        p = self.run_script('opencode-llm', 'summarize')
        self.assertEqual(p.returncode, 0, p.stderr)

    def test_task_reports_committed_changes_from_start(self):
        repo = self.repo()
        start = self.git(repo, 'rev-parse', 'HEAD')
        self.env['OC_MODE'] = 'commit'
        p = self.run_script('opencode-task', 'work', 'fix it', cwd=repo)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn(start, p.stderr)
        self.assertIn('agent-change', p.stdout)
        self.assertIn('1 file changed', p.stdout)
        self.assertEqual(self.git(repo, 'config', 'wt.work.session'), 'session-fixture')

    def test_timeout_preserves_session_and_worktree(self):
        self.env['OC_MODE'] = 'timeout'
        repo = self.repo()
        p = self.run_script('opencode-task', 'work', '-T', '1', 'fix it', cwd=repo)
        self.assertEqual(p.returncode, 124, p.stderr)
        self.assertEqual(self.git(repo, 'config', 'wt.work.session'), 'session-fixture')
        self.assertTrue((repo / '.worktrees/work/.git').exists())

    def test_portable_timeout_terminates_stubborn_process(self):
        # Remove GNU timeout from PATH while keeping the real shell utilities.
        for exe in ('bash', 'dirname', 'mkdir', 'mktemp', 'cat', 'jq', 'sleep', 'rm', 'rmdir'):
            path = shutil.which(exe)
            (self.bin / exe).symlink_to(path)
        self.env['PATH'] = str(self.bin)
        self.env['OC_MODE'] = 'timeout'
        p = self.run_script('opencode-llm', '-m', 'fixture', '-T', '1', 'summarize')
        self.assertEqual(p.returncode, 124, p.stderr)
        self.assertFalse(list(self.home.glob('opencode-llm.timeout.*')))


class ACP(Fixture):
    def setUp(self):
        super().setUp()
        self.fake('acp-fixture', '''import json, os, sys, time
for line in sys.stdin:
    req = json.loads(line)
    assert req['jsonrpc'] == '2.0'
    if 'id' not in req: continue
    if os.environ.get('ACP_MODE') == 'partial':
        sys.stdout.write('{'); sys.stdout.flush(); time.sleep(30)
    if os.environ.get('ACP_MODE') == 'eof': sys.exit(0)
    if os.environ.get('ACP_MODE') == 'bad_params':
        print('{"method":"session/update","params":null}', flush=True); continue
    if os.environ.get('ACP_MODE') == 'flood':
        while True:
            print('{"method":"heartbeat"}', flush=True); time.sleep(0.001)
    rid = req['id']; method = req['method']
    if method == 'initialize': result = {'protocolVersion':1, 'agentCapabilities':{}}
    elif method == 'session/new':
        assert req['params']['mcpServers'] == []
        result = {'sessionId':'session-fixture','configOptions':[{'id':'model','category':'model','options':[{'value':'fixture'}]}]}
    elif method == 'session/prompt':
        assert req['params']['sessionId'] == 'session-fixture'
        # Multiple messages in a single write expose select()/TextIO buffering bugs.
        for chunk in ['hello ', 'world']:
            sys.stdout.write(json.dumps({'method':'session/update','params':{'sessionId':'session-fixture','update':{'sessionUpdate':'agent_message_chunk','content':{'type':'text','text':chunk}}}})+'\\n')
        result = {'stopReason':'end_turn'}
    elif method == 'permission':
        print(json.dumps({'id':rid,'method':'session/request_permission','params':{'options':[{'kind':'reject_once','optionId':'reject'}]}}), flush=True)
        reply=json.loads(sys.stdin.readline()); assert reply['result']['outcome']['optionId']=='reject'
        result = {}
    elif method == 'session/set_config_option':
        assert req['params']['configId'] == 'model'; result = {}
    else:
        print(json.dumps({'id':rid,'error':{'code':-32601,'message':'fixture error'}}), flush=True); continue
    print(json.dumps({'jsonrpc':'2.0','id':rid,'result':result}), flush=True)
''')
        self.requests = [ {'id': 1, 'method': 'initialize', 'params': {}},
                          {'id': 2, 'method': 'session/new', 'params': {'cwd': str(self.home), 'mcpServers': []}},
                          {'id': 3, 'method': 'session/prompt', 'params': {'prompt': [{'type':'text','text':'test'}]}}]

    def call(self, requests=None, timeout='2'):
        return self.run_script('acp-call', 'acp-fixture', timeout,
                               data='\n'.join(json.dumps(r) for r in (requests or self.requests)))

    def test_buffered_updates_and_session_binding(self):
        p = self.call()
        self.assertEqual(p.returncode, 0, p.stderr)
        result = json.loads(p.stdout.splitlines()[-1])['result']
        self.assertEqual(result['content'][0]['text'], 'hello world')

    def test_timeouts_eof_rpc_errors_and_invalid_input(self):
        # Only the modes meant to time out get a short timeout; under load the
        # others could otherwise time out before the fake agent has started.
        for mode, code, timeout in [('partial', 124, '0.1'), ('flood', 124, '0.1'),
                                    ('eof', 6, '10'), ('bad_params', 6, '10')]:
            self.env['ACP_MODE'] = mode
            p = self.call(timeout=timeout)
            self.assertEqual(p.returncode, code, p.stderr)
        self.env.pop('ACP_MODE')
        self.assertEqual(self.call([{'id': 1, 'method': 'invalid'}]).returncode, 6)
        self.assertEqual(self.run_script('acp-call', 'acp-fixture', data='{bad').returncode, 2)

    def test_agent_permission_request_not_confused_with_response(self):
        self.assertEqual(self.call([{'id': 1, 'method': 'permission'}]).returncode, 0)

    def test_extractor_distinguishes_missing_from_empty(self):
        for data, code in [('{}', 1), ('{"id":2,"error":{}}', 6),
                           ('{"id":2,"result":{}}', 6), ('{"id":2,"result":{"items":[]}}', 0)]:
            p = self.run_script('acp-extract', '2', 'items', data=data)
            self.assertEqual(p.returncode, code, p.stderr)

    def test_probe_metadata_and_explicit_smoke_test(self):
        p = self.run_script('acp-capability-probe', '--agent', 'acp-fixture')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn('prompt', json.loads(p.stdout)[0])
        self.assertNotEqual(self.run_script('acp-capability-probe', '--spike').returncode, 0)
        p = self.run_script('acp-capability-probe', '--agent', 'acp-fixture', '--spike', '-m', 'fixture')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(json.loads(p.stdout)[0]['prompt']['stopReason'], 'end_turn')


class Statusline(Fixture):
    # Must match LAYOUT_MARGIN in statusline.sh.
    MARGIN = 4

    SESSION = '0123abcd-4567-89ef-0123-456789abcdef'

    def render(self, payload, columns=200, path=None):
        # Compact separators, as Claude Code sends it; the render-reuse key relies on them.
        env = {**self.env, 'COLUMNS': str(columns)}
        if path is not None:
            env['PATH'] = path
        p = subprocess.run([shutil.which('bash'), str(CLAUDE / '.claude/statusline.sh')], env=env,
                           cwd=self.home, input=json.dumps(payload, separators=(',', ':')),
                           text=True, capture_output=True, timeout=5)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stderr, '')
        return re.sub(r'\x1b\[[0-9;]*m', '', p.stdout)

    def wait_for(self, path, seconds=10):
        deadline = time.monotonic() + seconds
        while not path.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        return path.exists()

    def test_idle_timer_runs_reuse_the_render_until_the_width_changes(self):
        repo = self.repo()
        payload = {**self.full_payload(repo), 'cost': {'total_cost_usd': 1.5, 'total_duration_ms': 1000}}
        first = self.render(payload, 200)
        # Only the session clock moved: served from the saved render, so it needs neither jq
        # nor git (PATH holds only the fixture fakes).
        payload['cost']['total_duration_ms'] = 3000
        self.assertEqual(self.render(payload, 200, path=str(self.bin)), first)
        narrow = self.render(payload, 60)
        self.assertGreater(len(narrow.splitlines()), len(first.splitlines()))

    def test_idle_sessions_do_not_poll_the_usage_endpoint(self):
        self.write('.claude/.credentials.json', {'claudeAiOauth': {'accessToken': 'fixture-token'}})
        log = self.home / 'curl-log'
        self.env['CURL_LOG'] = str(log)
        self.fake('curl', 'import os\nwith open(os.environ["CURL_LOG"], "a") as f: f.write("call\\n")\nraise SystemExit(22)')
        payload = {'session_id': self.SESSION, 'cost': {'total_duration_ms': 1000}}
        body = json.dumps(payload, separators=(',', ':')).replace(':1000', ':')
        # A saved render with this exact key, too old to reuse: the session is idle.
        self.write(f'.cache/ai-status/render-{self.SESSION}', f'0\n200|{body}\nstale\n')
        self.render(payload)
        self.assertFalse(self.wait_for(log, 1))
        payload['context_window'] = {'used_percentage': 5}
        self.render(payload)
        self.assertTrue(self.wait_for(log))

    def full_payload(self, repo):
        now = int(time.time())
        return {'model': {'display_name': 'Opus 5.5'}, 'workspace': {'current_dir': str(repo)},
                'session_id': self.SESSION,
                'effort': {'level': 'high'}, 'thinking': {'enabled': True},
                'context_window': {'used_percentage': 42.7}, 'cost': {'total_cost_usd': 1.5},
                'rate_limits': {'five_hour': {'used_percentage': 30, 'resets_at': now + 9000},
                                'seven_day': {'used_percentage': 12, 'resets_at': now + 3 * 86400 + 60}}}

    def test_layout_fills_wide_panes_and_wraps_narrow_ones(self):
        repo = self.repo()
        (repo / 'file').write_text('changed\n')
        payload = self.full_payload(repo)
        self.assertEqual(len(self.render(payload, 250).splitlines()), 1)
        for columns in (120, 80, 60, 45):
            with self.subTest(columns=columns):
                lines = self.render(payload, columns).splitlines()
                self.assertGreater(len(lines), 1)
                for line in lines:
                    self.assertLessEqual(len(line), columns - self.MARGIN, line)
                text = '\n'.join(lines)
                for part in ('[Opus 5.5]', '✱high', '42%', 'fixture-main', '●1', 'w12% 3d', 'h30%'):
                    self.assertIn(part, text)
                self.assertIn('0123abcd', text)

    def test_home_directory_is_abbreviated(self):
        repo = self.repo()
        output = self.render({'workspace': {'current_dir': str(repo)}})
        self.assertIn('~/repo', output)
        self.assertNotIn(str(self.home), output)

    def test_rolled_over_windows_show_empty(self):
        past = int(time.time()) - 60
        self.write('.cache/ai-status/statusline-rate-limits', f'70|60|{past}|{past}\n')
        output = self.render({})
        self.assertIn('h0%', output)
        self.assertIn('w0%', output)

    def test_usage_token_never_reaches_disk_or_argv(self):
        self.write('.claude/.credentials.json', {'claudeAiOauth': {'accessToken': 'fixture-token'}})
        log = self.home / 'curl-log.json'
        self.env['CURL_LOG'] = str(log)
        self.fake('curl', 'import json, os, sys\n'
                          'record = {"argv": sys.argv[1:], "stdin": sys.stdin.read()}\n'
                          'tmp = os.environ["CURL_LOG"] + ".tmp"\n'
                          'open(tmp, "w").write(json.dumps(record))\n'
                          'os.rename(tmp, os.environ["CURL_LOG"])\n'
                          'raise SystemExit(22)')
        self.render({})
        deadline = time.monotonic() + 10
        while not log.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        record = json.loads(log.read_text())
        self.assertIn('Authorization: Bearer fixture-token', record['stdin'])
        self.assertFalse(any('fixture-token' in arg for arg in record['argv']))
        cache = self.home / '.cache/ai-status'
        self.assertFalse([p for p in cache.rglob('*') if p.is_file() and b'fixture-token' in p.read_bytes()])

    def test_payload_directory_and_zero_usage(self):
        repo = self.repo()
        self.write('.cache/ai-status/statusline-rate-limits', '80|90|0|0\n')
        output = self.render({'workspace': {'current_dir': str(repo)},
                              'rate_limits': {'five_hour': {'used_percentage': 0}, 'seven_day': {'used_percentage': 0}}})
        self.assertIn('fixture-main', output)
        self.assertIn('h0%', output)
        self.assertIn('w0%', output)

    def test_missing_usage_retains_currency_and_throttles_failure(self):
        self.write('.cache/ai-status/credit-currency', 'EUR\n')
        self.write('.cache/ai-status/fx-usd-EUR', '0.9\n')
        self.write('.claude/.credentials.json', {'claudeAiOauth': {'accessToken': 'fixture-token'}})
        log = self.home / 'curl-log'
        self.env['CURL_LOG'] = str(log)
        self.fake('curl', 'import os\nwith open(os.environ["CURL_LOG"], "a") as f: f.write("call\\n")\nraise SystemExit(22)')
        self.render({})
        # The fetch runs detached; wait for it rather than for a fixed time,
        # which a loaded machine overruns.
        deadline = time.monotonic() + 10
        while not log.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        time.sleep(0.15)
        self.render({})
        time.sleep(0.3)
        self.assertEqual(log.read_text().splitlines(), ['call'])
        self.assertEqual((self.home / '.cache/ai-status/credit-currency').read_text(), 'EUR\n')

    def test_malformed_fields_and_corrupt_cache(self):
        self.write('.cache/ai-status/statusline-rate-limits', 'bad|bad|bad|bad\n')
        output = self.render({'model': {'display_name': 7}, 'workspace': {'current_dir': 1},
                              'session_id': {}, 'effort': {'level': 'high\nescape'},
                              'thinking': 'yes', 'agent': ['x']}, columns=60)
        self.assertIn('[?]', output)
        self.assertIn('highescape', output)
        self.assertIn('h0%', output)
        self.assertNotIn('\x1b', output)


if __name__ == '__main__':
    unittest.main()
