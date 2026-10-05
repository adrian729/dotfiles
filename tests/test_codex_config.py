"""Offline checks for Codex config preservation, skills, and browser setup."""

import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tomllib
import unittest
from unittest.mock import patch

from test_claude_config import Fixture, ROOT

CODEX = ROOT / 'codex'
spec = importlib.util.spec_from_file_location('codex_merge', CODEX / 'merge_config.py')
merge_config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(merge_config)


class ConfigPreservation(Fixture):
    def setUp(self):
        super().setUp()
        self.baseline = self.write('baseline.toml', 'model = "portable"\n[tui]\nvim_mode_default = true\n')
        self.target = self.home / '.codex/config.toml'

    def install(self):
        merge_config.install(self.baseline, self.target)
        return tomllib.loads(self.target.read_text())

    def test_integrations_survive_and_other_settings_reset(self):
        self.write('.codex/config.toml', '''
model = "local-model"
approval_policy = "on-request"
mcp_oauth_credentials_store = "keyring"
mcp_oauth_callback_port = 18765
[tui]
theme = "local"
[features]
memories = true
[projects."/local/project"]
trust_level = "trusted"
[mcp_servers."server.with.dots"]
command = "npx"
args = ["-y", "example", "a\\nb"]
enabled = false
startup_timeout_sec = 15.5
disabled_tools = ["write"]
[mcp_servers."server.with.dots".env]
TOKEN = "test-only: \\"quoted\\" — café 🐈"
[plugins."example@local"]
enabled = true
[marketplaces.local]
source_type = "local"
source = "/local/marketplace"
[apps.connector_example]
enabled = true
[apps.connector_example.tools.write]
approval_mode = "prompt"
[skills]
max_bytes = 1234
[[skills.config]]
path = "/local/SKILL.md"
enabled = false
''')
        local = tomllib.loads(self.target.read_text())
        result = self.install()
        for key in (*merge_config.INTEGRATION_TABLES, 'mcp_oauth_credentials_store', 'mcp_oauth_callback_port'):
            self.assertEqual(result[key], local[key], key)
        self.assertEqual(result['model'], 'portable')
        self.assertEqual(result['tui'], {'vim_mode_default': True})
        self.assertEqual(result['skills'], {'config': local['skills']['config']})
        self.assertTrue({'features', 'projects', 'approval_policy'}.isdisjoint(result))

    def test_repo_replaces_whole_named_entry_and_duplicate_skill(self):
        self.baseline.write_text('''
mcp_oauth_callback_port = 20000
[mcp_servers.same]
url = "https://example.invalid/mcp"
[plugins."same@local"]
enabled = false
[[skills.config]]
path = "/same/SKILL.md"
enabled = true
''')
        self.write('.codex/config.toml', '''
mcp_oauth_callback_port = 10000
[mcp_servers.same]
command = "obsolete"
args = ["obsolete"]
[mcp_servers.extra]
command = "keep"
[plugins."same@local"]
enabled = true
[[skills.config]]
path = "/same/SKILL.md"
enabled = false
[[skills.config]]
path = "/extra/SKILL.md"
enabled = false
''')
        result = self.install()
        self.assertEqual(result['mcp_servers']['same'], {'url': 'https://example.invalid/mcp'})
        self.assertEqual(result['mcp_servers']['extra'], {'command': 'keep'})
        self.assertEqual(result['plugins']['same@local'], {'enabled': False})
        self.assertEqual(result['mcp_oauth_callback_port'], 20000)
        self.assertEqual(result['skills']['config'], [
            {'path': '/same/SKILL.md', 'enabled': True},
            {'path': '/extra/SKILL.md', 'enabled': False},
        ])

    def test_fresh_install_is_private_idempotent_and_keeps_other_files(self):
        for relative in ('auth.json', 'plugins/cache/example/data', 'skills/local/SKILL.md'):
            self.write('.codex/' + relative, 'keep me')
        self.assertEqual(self.install(), tomllib.loads(self.baseline.read_text()))
        first = self.target.read_bytes()
        self.install()
        self.assertEqual(self.target.read_bytes(), first)
        self.assertEqual(self.target.stat().st_mode & 0o777, 0o600)
        for relative in ('auth.json', 'plugins/cache/example/data', 'skills/local/SKILL.md'):
            self.assertEqual((self.target.parent / relative).read_text(), 'keep me')

    def test_invalid_toml_leaves_existing_config_untouched(self):
        for broken in ('local', 'baseline'):
            with self.subTest(broken=broken):
                self.baseline.write_text('model = "portable"\n')
                self.write('.codex/config.toml', 'model = "local"\n')
                (self.target if broken == 'local' else self.baseline).write_text('invalid = "TEST_SECRET')
                previous = self.target.read_bytes()
                p = subprocess.run([sys.executable, str(CODEX / 'merge_config.py'),
                                    str(self.baseline), str(self.target)], capture_output=True, text=True)
                self.assertNotEqual(p.returncode, 0)
                self.assertIn('invalid TOML', p.stderr)
                self.assertNotIn('TEST_SECRET', p.stderr)
                self.assertEqual(self.target.read_bytes(), previous)

    def test_file_symlink_is_replaced_without_writing_through_it(self):
        source = self.write('old-config.toml', '[mcp_servers.local]\ncommand = "keep"\n')
        self.target.parent.mkdir()
        self.target.symlink_to(source)
        previous = source.read_bytes()
        self.assertEqual(self.install()['mcp_servers']['local']['command'], 'keep')
        self.assertFalse(self.target.is_symlink())
        self.assertEqual(source.read_bytes(), previous)

    def test_folded_directory_and_broken_file_symlink_are_rejected(self):
        folder = self.home / 'folded'
        folder.mkdir()
        self.target.parent.symlink_to(folder, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'directory is symlinked'):
            self.install()
        self.assertFalse((folder / 'config.toml').exists())
        self.target.parent.unlink()
        self.target.parent.mkdir()
        self.target.symlink_to(self.home / 'missing')
        with self.assertRaisesRegex(ValueError, 'broken symlink'):
            self.install()
        self.assertTrue(self.target.is_symlink())

    def test_normal_symlinked_ancestor_is_supported(self):
        alias = self.home / 'alias'
        alias.symlink_to(self.home, target_is_directory=True)
        self.target = alias / '.codex/config.toml'
        self.assertEqual(self.install()['model'], 'portable')

    def test_interrupted_replace_preserves_file_and_cleans_temporary_file(self):
        self.write('.codex/config.toml', 'model = "local"\n')
        previous = self.target.read_bytes()
        with patch.object(merge_config.os, 'replace', side_effect=OSError('fixture failure')):
            with self.assertRaises(OSError):
                self.install()
        self.assertEqual(self.target.read_bytes(), previous)
        self.assertEqual(list(self.target.parent.glob('.config.toml.*')), [])

    def test_removed_integration_does_not_reappear(self):
        self.write('.codex/config.toml', '[mcp_servers.extra]\ncommand = "remove-me"\n')
        self.install()
        self.target.write_text('model = "portable"\n')
        self.assertNotIn('mcp_servers', self.install())

    def test_installer_handles_codex_home_parse_failure_and_old_python(self):
        package = self.home / 'farm/codex'
        shutil.copytree(CODEX, package)
        self.write('farm/lib/common.sh', '''
brew_shellenv() { :; }
brew_can_pour() { command -v brew >/dev/null; }
ensure_cmd() { command -v "$1" >/dev/null; }
ensure_node() { return 1; }
ensure_uv() { command -v uv >/dev/null; }
have() { command -v "$1" >/dev/null; }
info() { echo "$*"; }
warn() { echo "$*" >&2; }
''')
        self.fake('codex', 'raise SystemExit("Unexpected model request")')
        (self.bin / 'python3').symlink_to(sys.executable)
        self.env['CODEX_HOME'] = str(self.home / 'custom-codex')
        target = self.write('custom-codex/config.toml', '[mcp_servers.local]\ncommand = "keep"\n')
        p = subprocess.run(['bash', str(package / 'install.sh')], env=self.env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(tomllib.loads(target.read_text())['mcp_servers']['local']['command'], 'keep')
        self.assertFalse(self.target.exists())
        target.write_text('invalid = "TEST_SECRET')
        p = subprocess.run(['bash', str(package / 'install.sh')], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual(target.read_text(), 'invalid = "TEST_SECRET')
        self.assertNotIn('TEST_SECRET', p.stderr)

        # An older system Python must not prevent using Homebrew's newer one.
        target.write_text('[mcp_servers.local]\ncommand = "keep"\n')
        (self.bin / 'python3').unlink()
        self.fake('python3', 'raise SystemExit("Fixture Python lacks tomllib")')
        brew_prefix = self.home / 'brew-python'
        (brew_prefix / 'bin').mkdir(parents=True)
        (brew_prefix / 'bin/python3').symlink_to(sys.executable)
        self.fake('brew', f'''import sys
if sys.argv[1:] == ['--prefix', 'python']:
    print({str(brew_prefix)!r})
elif sys.argv[1:] != ['install', 'python']:
    raise SystemExit('Unexpected brew call')
''')
        p = subprocess.run(['bash', str(package / 'install.sh')], env=self.env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(tomllib.loads(target.read_text())['mcp_servers']['local']['command'], 'keep')

        # Without a pourable python (Intel macOS), a uv-managed one runs the merge.
        (self.bin / 'brew').unlink()
        self.fake('uv', f'''import os, sys
args = sys.argv[1:]
assert args[:5] == ['run', '--quiet', '--no-project', '--python', '3.13'], args
assert args[5] == 'python', args
os.execv({sys.executable!r}, [{sys.executable!r}, *args[6:]])
''')
        target.write_text('[mcp_servers.local]\ncommand = "keep"\n')
        p = subprocess.run(['bash', str(package / 'install.sh')], env=self.env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(tomllib.loads(target.read_text())['mcp_servers']['local']['command'], 'keep')

    @unittest.skipUnless(shutil.which('stow'), 'GNU Stow is unavailable')
    def test_stow_deploys_shared_skills_but_no_codex_config_or_helpers(self):
        p = subprocess.run([shutil.which('stow'), '--no-folding', '-d', str(ROOT),
                            '-t', str(self.home), 'codex', 'agents'], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        for name in ('ai-instruction-file-authoring', 'markdown-no-wrap'):
            deployed = self.home / '.agents/skills' / name / 'SKILL.md'
            original = ROOT / 'agents/.agents/skills' / name / 'SKILL.md'
            self.assertEqual(deployed.resolve(), original.resolve())
            claude = ROOT / 'claude/.claude/skills' / name / 'SKILL.md'
            self.assertEqual(claude.resolve(), original.resolve())
        for name in ('.codex/config.toml', 'merge_config.py', 'README.md', 'install.sh',
                     'install_playwright.sh', '__pycache__'):
            self.assertFalse((self.home / name).exists(), name)


class PlaywrightInstallation(Fixture):
    def setUp(self):
        super().setUp()
        self.package = self.home / 'farm/codex'
        self.package.mkdir(parents=True)
        shutil.copy(CODEX / 'install_playwright.sh', self.package)
        self.write('farm/lib/common.sh', '''
brew_shellenv() { :; }
ensure_node() { return 0; }
have() { command -v "$1" >/dev/null; }
info() { echo "$*"; }
warn() { echo "$*" >&2; }
''')
        self.env['CODEX_HOME'] = str(self.home / 'custom-codex')
        self.skill = self.home / 'custom-codex/skills/playwright-cli'
        self.config = self.home / '.playwright/cli.config.json'
        self.write('npm-root/@playwright/cli/skills/playwright-cli/SKILL.md', 'upstream skill')
        self.write('npm-root/@playwright/cli/skills/playwright-cli/references/example.md', 'reference')
        self.fake('npm', '''import os, pathlib, sys
home = pathlib.Path(os.environ['HOME'])
if sys.argv[1:] == ['root', '-g']:
    print(home / 'npm-root')
else:
    raise SystemExit('Unexpected npm call: ' + repr(sys.argv[1:]))
''')
        self.fake('playwright-cli', '''import sys
if sys.argv[1:] != ['install-browser', 'chromium', '--no-shell']:
    raise SystemExit('Unexpected Playwright call')
''')

    def install(self):
        return subprocess.run(['bash', str(self.package / 'install_playwright.sh')],
                              env=self.env, capture_output=True, text=True, timeout=10)

    def test_new_install_and_reinstall_preserve_local_skill_and_config(self):
        import json

        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.skill / 'SKILL.md').read_text(), 'upstream skill')
        self.assertEqual((self.skill / 'references/example.md').read_text(), 'reference')
        self.assertEqual(json.loads(self.config.read_text())['browser']['launchOptions']['channel'],
                         'chromium')
        self.assertFalse((self.home / '.codex').exists())
        (self.skill / 'SKILL.md').write_text('local skill')
        self.config.write_text('{"browser":{"browserName":"firefox"}}')
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.skill / 'SKILL.md').read_text(), 'local skill')
        self.assertEqual(self.config.read_text(), '{"browser":{"browserName":"firefox"}}')

    def test_failed_browser_install_returns_failure_and_retry_instruction(self):
        self.fake('playwright-cli', 'raise SystemExit(1)')
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('retry: bash codex/install_playwright.sh', result.stderr)
        self.assertNotIn('Chromium are installed', result.stdout)

    def test_failed_npm_install_does_not_create_skill_or_config(self):
        (self.bin / 'playwright-cli').unlink()
        self.fake('npm', 'raise SystemExit(1)')
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('CLI installation failed', result.stderr)
        self.assertFalse(self.skill.exists())
        self.assertFalse(self.config.exists())
