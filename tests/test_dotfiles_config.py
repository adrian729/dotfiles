"""Offline regressions for bootstrap, shell, editor and tmux configuration."""
import json
import os
from pathlib import Path
import pty
import shlex
import shutil
import subprocess
import unittest

from test_claude_config import Fixture, ROOT

ZSH = shutil.which('zsh')
NVIM = shutil.which('nvim')
TMUX = shutil.which('tmux')


class DotfilesFixture(Fixture):
    def setUp(self):
        super().setUp()
        self.env.update(ZDOTDIR=str(self.home),
                        XDG_DATA_HOME=str(self.home / '.local/share'),
                        XDG_STATE_HOME=str(self.home / '.local/state'))

    def run_command(self, *args, data='', **kwargs):
        return subprocess.run(list(map(str, args)), input=data, text=True,
                              capture_output=True, env=self.env, cwd=self.home,
                              timeout=15, **kwargs)


class Bootstrap(DotfilesFixture):
    packages = ('opencode', 'claude', 'codex', 'agents', 'ollama', 'ghostty',
                'kitty', 'nvim', 'clangd', 'tmux', 'zsh', 'lf', 'bettercmdtab')

    def setUp(self):
        super().setUp()
        self.installer = self.write('farm/install.sh', (ROOT / 'install.sh').read_text())
        self.write('farm/lib/common.sh', '''
brew_bootstrap() { return 0; }
is_linux() { return 0; }
''')
        for package in self.packages:
            self.write(f'farm/{package}/install.sh', f'echo INSTALL-{package}\n'
                       f'[ "$FAIL_INSTALL" != "{package}" ]\n')
        self.fake('stow', '''import os, sys
name = sys.argv[-1]
assert '--no-folding' in sys.argv
print('STOW-' + name)
raise SystemExit(23 if name == os.environ.get('FAIL_STOW') else 0)
''')

    def test_failures_skip_affected_installer_and_continue(self):
        self.env.update(FAIL_STOW='zsh', FAIL_INSTALL='tmux')
        p = self.run_command('bash', self.installer, '-y')
        self.assertEqual(p.returncode, 1, p.stderr)
        self.assertNotIn('INSTALL-zsh', p.stdout)
        self.assertIn('INSTALL-lf', p.stdout)
        self.assertIn('zsh: stow', p.stderr)
        self.assertIn('tmux: install', p.stderr)
        self.assertNotIn('Setup complete!', p.stdout)

    def test_pre_stow_failure_skips_stow_and_install(self):
        self.write('farm/claude/pre_stow.sh', 'exit 19\n')
        p = self.run_command('bash', self.installer, '-y')
        self.assertEqual(p.returncode, 1)
        self.assertNotIn('STOW-claude', p.stdout)
        self.assertNotIn('INSTALL-claude', p.stdout)
        self.assertIn('INSTALL-lf', p.stdout)

    def test_blacklist_without_final_newline(self):
        self.write('farm/.stow_blacklist.local', '# local\nlf')
        p = self.run_command('bash', self.installer, '-y')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn('STOW-lf', p.stdout)
        self.assertNotIn('INSTALL-lf', p.stdout)

    def test_declining_packages_does_not_run_their_installers(self):
        self.write('farm/.stow_blacklist.local', '\n'.join(
            name for name in self.packages if name not in ('zsh', 'lf')))
        master, slave = pty.openpty()
        try:
            p = subprocess.Popen(['bash', str(self.installer)], stdin=slave,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 env=self.env, cwd=self.home, text=True)
            os.write(master, b'n\nn\ny\n')
            out, err = p.communicate(timeout=10)
        finally:
            os.close(master)
            os.close(slave)
        self.assertEqual(p.returncode, 0, err)
        self.assertNotIn('INSTALL-zsh', out)
        self.assertNotIn('STOW-zsh', out)
        self.assertIn('INSTALL-lf', out)

    def test_llvm_preserves_local_wrapper_and_unrelated_symlink(self):
        wrapper = self.write('.local/bin/clangd', '#!/bin/sh\necho local\n')
        wrapper.chmod(0o755)
        target = self.write('local-formatter', '#!/bin/sh\nexit 0\n')
        target.chmod(0o755)
        link = wrapper.parent / 'clang-format'
        link.symlink_to(target)
        self.env['PATH'] = str(wrapper.parent) + ':' + self.env['PATH']
        self.env['DOTFILES_COMMON_SH'] = '1'
        p = self.run_command('bash', '-c',
                             'brew_shellenv() { :; }; warn() { echo "$*" >&2; }; '
                             'source "$1"; ensure_llvm clangd clang-format',
                             'fixture', ROOT / 'clangd/install.sh')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(wrapper.read_text(), '#!/bin/sh\necho local\n')
        self.assertFalse(wrapper.is_symlink())
        self.assertEqual(link.readlink(), target)

    def test_clipboard_dependency_installs_missing_display_helper(self):
        for existing, expected in [('wl-copy', 'xclip'), ('xclip', 'wl-clipboard')]:
            with self.subTest(existing=existing):
                p = self.run_command('bash', '-c', '''
source "$1"
is_macos() { return 1; }
have() { [ "$1" = "$EXISTING" ]; }
pkg_install() { printf 'INSTALL:%s\n' "$*"; }
ensure_clipboard
'''.replace('$EXISTING', existing), 'fixture', ROOT / 'lib/common.sh')
                self.assertEqual(p.returncode, 0, p.stderr)
                self.assertIn('INSTALL:' + expected + '\n', p.stdout)


@unittest.skipUnless(ZSH, 'zsh is required')
class Shell(DotfilesFixture):
    def zsh(self, code, *args):
        return self.run_command(ZSH, '-d', '-f', '-c', code, 'fixture', *args)

    def test_fzf_excludes_hidden_and_quotes_shell_characters(self):
        name = "a 'file' $(touch should-not-exist).txt"
        self.env['PICK'] = name
        self.fake('fd', '''import sys
assert sys.argv[1:] == ['--type', 'f'], sys.argv
print('visible')
''')
        self.fake('fzf', r'''import os, sys
assert sys.stdin.read() == 'visible\n'
assert '--no-multi' in sys.argv
print(os.environ['PICK'])
''')
        p = self.zsh('source "$1"; zle() { :; }; LBUFFER=""; '
                     '_fzf_file_no_hidden; eval "set -- $LBUFFER"; '
                     '(( $# == 1 )) || exit 2; print -r -- "$1"',
                     ROOT / 'zsh/.config/zsh/fzf.zsh')
        self.assertEqual((p.returncode, p.stdout.rstrip('\n')), (0, name), p.stderr)
        self.assertFalse((self.home / 'should-not-exist').exists())

    def test_xdg_directories_are_preserved(self):
        keys = ('XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME')
        self.env.update({key: str(self.home / key) for key in keys})
        p = self.zsh('source "$1"; print -rl -- "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" '
                     '"$XDG_DATA_HOME" "$XDG_STATE_HOME"', ROOT / 'zsh/.config/zsh/.zshenv')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout.splitlines(), [self.env[key] for key in keys])

    def test_dotfiles_alias_resolves_checkout_through_symlink(self):
        source = self.write('clone with spaces/zsh/.config/zsh/aliases.zsh',
                            (ROOT / 'zsh/.config/zsh/aliases.zsh').read_text())
        link = self.home / 'aliases.zsh'
        link.symlink_to(source)
        self.fake('git', 'import json, sys; print(json.dumps(sys.argv[1:]))')
        p = self.zsh('compdef() { :; }; source "$1"; eval "dotfiles status"', link)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(json.loads(p.stdout), ['-C', str(self.home / 'clone with spaces'), 'status'])

    def test_lf_marker_is_unique_cleanup_and_exit_status(self):
        destination = self.home / 'destination with spaces'
        destination.mkdir()
        self.env['DEST'] = str(destination)
        self.fake('lf', r'''import os, pathlib, sys
marker = pathlib.Path(os.environ['LF_NO_CD_FILE'])
with (pathlib.Path.home() / 'markers').open('a') as f: f.write(str(marker) + '\n')
pathlib.Path(sys.argv[1].split('=', 1)[1]).write_text(os.environ['DEST'])
if 'no-cd' in sys.argv: marker.touch()
if 'fail' in sys.argv: raise SystemExit(7)
''')
        p = self.zsh('compdef() { :; }; source "$1"; '
                     'lf no-cd; print -r -- "$PWD"; '
                     'lf fail; print -r -- "exit:$? $PWD"; '
                     'lf; print -r -- "$PWD"', ROOT / 'zsh/.config/zsh/aliases.zsh')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout.splitlines(), [str(self.home), 'exit:7 ' + str(self.home), str(destination)])
        markers = (self.home / 'markers').read_text().splitlines()
        self.assertEqual(len(set(markers)), 3)
        self.assertTrue(all(not Path(path).parent.exists() for path in markers))

    def test_lazy_nvm_activates_default_node(self):
        nvm_source = Path(os.environ.get('NVM_DIR', str(Path.home() / '.nvm'))) / 'nvm.sh'
        if not nvm_source.is_file():
            self.skipTest('nvm.sh is required for the integration test')
        self.write('.nvm/nvm.sh', nvm_source.read_text())
        self.write('.nvm/alias/default', 'v22.0.0\n')
        node = self.write('.nvm/versions/node/v22.0.0/bin/node', '#!/bin/sh\necho v22.0.0\n')
        node.chmod(0o755)
        rc = (ROOT / 'zsh/.config/zsh/.zshrc').read_text()
        loader = rc[rc.index('export NVM_DIR='):rc.index('unset _nvm_cmd') + len('unset _nvm_cmd')]
        self.write('nvm-loader.zsh', loader)
        p = self.zsh('source "$1"; node --version', self.home / 'nvm-loader.zsh')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout.splitlines()[-1], 'v22.0.0')


class Clipboard(DotfilesFixture):
    def setUp(self):
        super().setUp()
        self.env.pop('WAYLAND_DISPLAY', None)
        self.env.pop('DISPLAY', None)
        self.fake('pbcopy', 'raise SystemExit(1)')
        for name in ('wl-copy', 'xclip', 'xsel'):
            self.fake(name, rf'''import os, pathlib, sys
data = sys.stdin.buffer.read()
with (pathlib.Path.home() / 'calls').open('a') as f: f.write('{name}\n')
if os.environ.get('FAIL_HELPER') == '{name}': raise SystemExit(1)
(pathlib.Path.home() / 'clipboard').write_bytes(data)
''')

    def copy(self):
        return self.run_command('bash', ROOT / 'tmux/.local/scripts/tmux-clipboard', data='a\nb\n\n')

    def test_x11_ignores_installed_wayland_helper(self):
        self.env['DISPLAY'] = ':99'
        p = self.copy()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual((self.home / 'calls').read_text(), 'xclip\n')
        self.assertEqual((self.home / 'clipboard').read_text(), 'a\nb\n\n')

    def test_wayland_failure_replays_full_input_to_x11(self):
        self.env.update(WAYLAND_DISPLAY='wayland-0', DISPLAY=':99', FAIL_HELPER='wl-copy')
        p = self.copy()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual((self.home / 'calls').read_text(), 'wl-copy\nxclip\n')
        self.assertEqual((self.home / 'clipboard').read_text(), 'a\nb\n\n')
        self.assertFalse(list(self.home.glob('tmux-clipboard.*')))

    def test_no_display_reports_failure(self):
        p = self.copy()
        self.assertEqual(p.returncode, 1)
        self.assertIn('no working clipboard helper', p.stderr)
        self.assertFalse((self.home / 'calls').exists())


class BetterCmdTab(DotfilesFixture):
    def setUp(self):
        super().setUp()
        shutil.copytree(ROOT / 'bettercmdtab', self.home / 'farm/bettercmdtab')
        self.write('farm/lib/common.sh', '''
brew_shellenv() { :; }
is_macos() { return 0; }
have() { return 1; }
warn() { echo "$*" >&2; }
''')
        self.fake('defaults', 'raise SystemExit(0)')
        self.fake('pgrep', 'raise SystemExit(1)')

    def test_config_and_schema_replace_links_without_writing_repo(self):
        source = self.home / 'farm/bettercmdtab/.config/bettercmdtab'
        target = self.home / '.config/bettercmdtab'
        target.mkdir(parents=True)
        originals = {}
        for name in ('config.json', 'schema.json'):
            originals[name] = (source / name).read_bytes()
            (target / name).symlink_to(source / name)
        p = self.run_command('bash', self.home / 'farm/bettercmdtab/install.sh')
        self.assertEqual(p.returncode, 0, p.stderr)
        for name in originals:
            self.assertFalse((target / name).is_symlink())
            self.assertEqual((target / name).read_bytes(), originals[name])
            (target / name).write_text('application update')
            self.assertEqual((source / name).read_bytes(), originals[name])

    def test_folded_parent_is_rejected(self):
        source = self.home / 'farm/bettercmdtab/.config'
        (self.home / '.config').symlink_to(source)
        before = (source / 'bettercmdtab/config.json').read_bytes()
        p = self.run_command('bash', self.home / 'farm/bettercmdtab/install.sh')
        self.assertEqual(p.returncode, 1, p.stderr)
        self.assertIn('directory symlink', p.stderr)
        self.assertEqual((source / 'bettercmdtab/config.json').read_bytes(), before)


@unittest.skipUnless(TMUX, 'tmux is required')
class Sessions(DotfilesFixture):
    def setUp(self):
        super().setUp()
        self.socket = self.home / 'tmux.sock'
        self.env['TMUX'] = 'fixture'
        self.fake('fzf', "import os, sys; sys.stdin.read(); print(os.environ['PICK'])")
        # Use an isolated real server; only the client switch and ready command are suppressed.
        self.fake('tmux', f'''import os, subprocess, sys
args = sys.argv[1:]
if args[0] in ('switch-client', 'attach-session', 'send-keys'):
    print('CLIENT', args[0], args[2])
else:
    raise SystemExit(subprocess.call([{TMUX!r}, '-S', {str(self.socket)!r}, '-f', '/dev/null', *args]))
''')
        self.addCleanup(lambda: subprocess.run([TMUX, '-S', str(self.socket), 'kill-server'],
                                               capture_output=True, env=self.env))

    def tmux(self, *args):
        return self.run_command(TMUX, '-S', self.socket, '-f', '/dev/null', *args)

    def test_previous_pane_binding_can_forward_ctrl_backslash(self):
        p = self.tmux('new-session', '-d', '-s', 'fixture', 'stty -isig; cat')
        self.assertEqual(p.returncode, 0, p.stderr)
        config = (ROOT / 'tmux/.config/tmux/tmux.conf').read_text()
        binding = next(line for line in config.splitlines() if line.startswith(r'bind -n C-\\ '))
        fragment = self.write('binding.conf', 'is_vim="true"\n' + binding + '\n')
        p = self.tmux('source-file', fragment)
        self.assertEqual(p.returncode, 0, p.stderr)
        stored = self.tmux('list-keys', '-T', 'root').stdout.splitlines()
        binding = next(shlex.split(line) for line in stored if 'select-pane -l' in line)
        p = self.tmux('if-shell', 'true', binding[-2], binding[-1])
        self.assertEqual(p.returncode, 0, p.stderr)

    def test_same_basename_keeps_distinct_sessions_and_reuses_them(self):
        first = self.home / 'a/project'
        second = self.home / 'b/project'
        first.mkdir(parents=True)
        second.mkdir(parents=True)
        for path in (first, second, second):
            self.env['PICK'] = str(path)
            p = self.run_command('bash', ROOT / 'tmux/.local/scripts/tmux-sessionizer', self.home)
            self.assertEqual(p.returncode, 0, p.stderr)
        p = self.tmux('list-sessions', '-F', '#{session_name}|#{@sessionizer_root}')
        sessions = dict(line.split('|', 1) for line in p.stdout.splitlines())
        self.assertEqual(len(sessions), 2, sessions)
        self.assertEqual(sessions.pop('project'), str(first))
        self.assertEqual(list(sessions.values()), [str(second)])
        # A remembered collision session is reused even after the ordinary name is freed.
        self.tmux('kill-session', '-t', '=project')
        p = self.run_command('bash', ROOT / 'tmux/.local/scripts/tmux-sessionizer', self.home)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(len(self.tmux('list-sessions').stdout.splitlines()), 1)


@unittest.skipUnless(NVIM, 'Neovim is required')
class Treesitter(DotfilesFixture):
    def test_bootstrap_waits_for_completion_and_reports_failure(self):
        script = self.write('treesitter-test.lua', '''
local completed = false
package.preload['tree-sitter-rstml'] = function() return { init = function() end } end
package.preload['nvim-treesitter'] = function()
  return { install = function()
    vim.defer_fn(function() completed = true end, 50)
    return { wait = function(_, timeout)
      assert(vim.wait(timeout, function() return completed end))
      if vim.env.TS_RESULT == 'error' then error('download failed') end
      return vim.env.TS_RESULT == 'success'
    end }
  end }
end
local spec = dofile(vim.env.TS_SPEC)
spec[1].config()
assert(completed, 'editor exited before parsers finished')
vim.cmd('qa!')
''')
        self.env.update(DOTFILES_NVIM_BOOTSTRAP='1', TS_SPEC=str(ROOT / 'nvim/.config/nvim/lua/plugins/treesitter.lua'))
        for result in ('success', 'failure', 'error'):
            with self.subTest(result=result):
                self.env['TS_RESULT'] = result
                p = self.run_command(NVIM, '--headless', '-u', 'NONE', '-l', script)
                self.assertEqual(p.returncode, 0 if result == 'success' else 1, p.stderr)


if __name__ == '__main__':
    unittest.main()
