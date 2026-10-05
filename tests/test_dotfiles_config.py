"""Offline regressions for bootstrap, shell, editor and tmux configuration."""
import json
import os
from pathlib import Path
import pty
import shlex
import shutil
import subprocess
import tarfile
import unittest

from test_claude_config import Fixture, ROOT

ZSH = shutil.which('zsh')
JQ = shutil.which('jq', path='/usr/bin:/bin')
CURL = shutil.which('curl', path='/usr/bin:/bin')
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
# Restow, so a fold left by an older install is replaced by per-file links.
assert '-R' in sys.argv
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


class Common(DotfilesFixture):
    """lib/common.sh: choosing between bottles, release builds and source builds."""

    def common(self, script, os_name='macos'):
        prelude = (f'source "$1"; DOTFILES_OS={os_name}; '
                   'warn() { echo "$*" >&2; }; info() { echo "$*"; }; ')
        return self.run_command('bash', '-c', prelude + script, 'fixture', ROOT / 'lib/common.sh')

    def brew(self, prefix, formulae, deps=(), casks=()):
        self.env['BREW_FIXTURE'] = json.dumps({'prefix': prefix, 'formulae': formulae,
                                               'deps': list(deps), 'casks': list(casks)})
        self.fake('brew', r"""import json, os, sys
cfg = json.loads(os.environ['BREW_FIXTURE'])
args = sys.argv[1:]
names = [a for a in args[1:] if not a.startswith('-')]
if args == ['--prefix']: print(cfg['prefix'])
elif args[0] in ('deps', 'info') and '--formula' in args and set(names) & set(cfg['casks']):
    raise SystemExit('Error: No available formula with the name "%s".' % names[0])
elif args[0] == 'deps': print('\n'.join(cfg['deps']))
elif args[0] == 'info':
    print(json.dumps({'formulae': [cfg['formulae'][n] for n in names if n in cfg['formulae']],
                      'casks': [{'token': n} for n in names if n in cfg['casks']]}))
else:
    with open(os.path.join(os.environ['HOME'], 'brew-calls'), 'a') as f: f.write(' '.join(args) + '\n')
""")
        self.fake('sw_vers', 'print("15.7.2")')

    @staticmethod
    def formula(name, tags, installed=False, outdated=False):
        return {'name': name, 'installed': [{'version': '1'}] if installed else [],
                'outdated': outdated, 'bottle': {'stable': {'files': {t: {} for t in tags}}}}

    def can_pour(self, *names, os_name='macos'):
        p = self.common('brew_can_pour ' + ' '.join(names) + ' && echo POUR || echo BUILD', os_name)
        return p.stdout.strip()

    @unittest.skipUnless(JQ, 'jq is required')
    def test_bottle_tags_follow_brew_architecture_and_older_macos(self):
        f = self.formula
        self.brew('/usr/local', {'a': f('a', ['arm64_sequoia', 'sonoma']),
                                 'b': f('b', ['arm64_sequoia', 'arm64_sonoma']),
                                 'c': f('c', ['tahoe'])})
        self.assertEqual([self.can_pour(n) for n in 'abc'], ['POUR', 'BUILD', 'BUILD'])
        self.brew('/opt/homebrew', {'b': f('b', ['arm64_sonoma'])})
        self.assertEqual(self.can_pour('b'), 'POUR')
        self.brew('/home/linuxbrew/.linuxbrew', {'d': f('d', ['x86_64_linux', 'arm64_linux'])})
        p = self.common('machine_arch() { echo x86_64; }; brew_can_pour d && echo POUR', 'linux')
        self.assertEqual(p.stdout.strip(), 'POUR', p.stderr)

    @unittest.skipUnless(JQ, 'jq is required')
    def test_dependencies_must_pour_and_intel_never_upgrades_them(self):
        f = self.formula
        tool = f('tool', ['sonoma', 'arm64_sonoma'])
        self.brew('/usr/local', {'tool': tool, 'dep': f('dep', ['arm64_sonoma'])}, deps=['dep'])
        self.assertEqual(self.can_pour('tool'), 'BUILD')
        self.brew('/usr/local', {'tool': tool, 'dep': f('dep', [], installed=True)}, deps=['dep'])
        self.assertEqual(self.can_pour('tool'), 'POUR')
        # An installed llvm linked against z3 broke when a z3 upgrade poured.
        outdated = {'tool': tool,
                    'dep': f('dep', ['sonoma', 'arm64_sonoma'], installed=True, outdated=True)}
        self.brew('/usr/local', outdated, deps=['dep'])
        self.assertEqual(self.can_pour('tool'), 'BUILD')
        self.brew('/opt/homebrew', outdated, deps=['dep'])
        self.assertEqual(self.can_pour('tool'), 'POUR')

    @unittest.skipUnless(JQ, 'jq is required')
    def test_cask_only_name_is_not_a_pourable_formula(self):
        # `brew install codex` would install the cask instead of the release build.
        self.brew('/opt/homebrew', {}, casks=['codex'])
        self.assertEqual(self.can_pour('codex'), 'BUILD')

    def test_ensure_cmd_prefers_bottle_then_release_then_source(self):
        script = r'''
brew_can_pour() { [ "$POUR" = 1 ]; }
install_tool() { touch "$HOME/bin/tool" && chmod +x "$HOME/bin/tool"; }
brew() { echo "brew $*"; [ "$1" = install ] && install_tool; }
have() { [ "$1" = brew ] || [ -x "$HOME/bin/$1" ]; }
prebuilt_install() {
  echo "prebuilt $1"
  case "$PREBUILT" in
  ok) install_tool ;;
  fail) return 1 ;;
  *) return 2 ;;
  esac
}
ensure_cmd tool formula; echo "rc=$?"
'''
        cases = [('1', 'ok', ['brew install --formula formula', 'rc=0']),
                 ('0', 'ok', ['prebuilt tool', 'rc=0']),
                 ('0', 'fail', ['prebuilt tool', 'rc=1']),
                 ('0', 'none', ['prebuilt tool', 'brew install --formula formula', 'rc=0'])]
        for pour, prebuilt, expected in cases:
            with self.subTest(pour=pour, prebuilt=prebuilt):
                (self.bin / 'tool').unlink(missing_ok=True)
                self.env.update(POUR=pour, PREBUILT=prebuilt)
                p = self.common(script)
                lines = [line for line in p.stdout.splitlines()
                         if line.startswith(('brew ', 'prebuilt ', 'rc='))]
                self.assertEqual(lines, expected, p.stderr)

    def test_failed_release_install_never_falls_back_to_a_source_build(self):
        script = r'''
brew_can_pour() { return 1; }
brew() { echo "brew $*"; }
have() { [ "$1" = brew ]; }
uv_tool() { return 2; }   # uv's own status when PyPI is unreachable
ensure_cmd "$TOOL"; echo "rc=$?"
'''
        for tool in ('ruff', 'eza'):   # eza: macOS without cargo
            with self.subTest(tool=tool):
                self.env['TOOL'] = tool
                p = self.common(script)
                self.assertEqual(p.stdout.splitlines()[-1:], ['rc=1'], p.stderr)
                self.assertNotIn('brew install', p.stdout)

    def test_linux_without_brew_uses_distro_packages_for_tools_without_releases(self):
        p = self.common(r'''
have() { [ "$1" != brew ] && [ -x "$HOME/bin/$1" ]; }
pkg_install() { echo "pkg $*"; touch "$HOME/bin/$1"; chmod +x "$HOME/bin/$1"; }
ensure_cmd tmux; echo "rc=$?"
''', 'linux')
        self.assertEqual(p.stdout.splitlines(), ['pkg tmux', 'rc=0'], p.stderr)

    @unittest.skipUnless(CURL, 'curl is required')
    def test_release_archives_install_binaries_and_trees(self):
        (self.bin / 'curl').unlink()  # file:// URLs only; nothing leaves the machine
        src = self.home / 'src'
        tool = self.write('src/tool-1.0-x86_64/tool', '#!/bin/sh\necho tool\n')
        self.write('src/tree/bin/srv', '#!/bin/sh\necho srv\n')
        self.write('src/tree/main.lua', '-- runtime\n')
        with tarfile.open(src / 'tool.tar.gz', 'w:gz') as tar:
            tar.add(tool.parent, arcname=tool.parent.name)
        with tarfile.open(src / 'tree.tar.gz', 'w:gz') as tar:
            for entry in ('bin', 'main.lua'):
                tar.add(src / 'tree' / entry, arcname=entry)
        subprocess.run(['gzip', '-k', str(tool)], check=True)
        p = self.common(f'''
prebuilt_bin "file://{src}/tool.tar.gz" tool &&
prebuilt_bin "file://{tool}.gz" "gz:tool" &&
prebuilt_tree "file://{src}/tree.tar.gz" srv &&
prebuilt_tree "file://{src}/tree.tar.gz" srv''')
        self.assertEqual(p.returncode, 0, p.stderr)
        for name in ('tool', 'gz'):
            installed = self.home / '.local/bin' / name
            self.assertTrue(os.access(installed, os.X_OK), name)
            self.assertEqual(installed.read_text(), tool.read_text())
        tree = self.home / '.local/opt/srv'
        self.assertEqual(sorted(x.name for x in tree.iterdir()), ['bin', 'main.lua'])
        # Nothing left behind: no old copy, no staging directory.
        self.assertEqual([x.name for x in tree.parent.iterdir()], ['srv'])
        p = self.common(f'prebuilt_bin "file://{src}/tool.tar.gz" missing:nothing-here')
        self.assertNotEqual(p.returncode, 0)

    def test_asset_templates_use_tag_or_version(self):
        p = self.common('gh_latest_tag() { echo v1.2.3; }; '
                        'gh_asset_url o/r "x-{tag}-{version}.tgz"; gh_asset_url o/r plain.tgz')
        self.assertEqual(p.stdout.splitlines(), [
            'https://github.com/o/r/releases/download/v1.2.3/x-v1.2.3-1.2.3.tgz',
            'https://github.com/o/r/releases/latest/download/plain.tgz'])

    def test_every_platform_has_a_release_build(self):
        tools = ('bat fd starship zoxide rg fzf jq lf shellcheck stylua marksman rust-analyzer '
                 'tree-sitter codex lua-language-server nvim ruff ty clangd clang-format')
        for os_name, arch in [('macos', 'x86_64'), ('macos', 'arm64'),
                              ('linux', 'x86_64'), ('linux', 'arm64')]:
            with self.subTest(os=os_name, arch=arch):
                p = self.common(f'''machine_arch() {{ echo {arch}; }}
gh_latest_tag() {{ echo v9; }}
prebuilt_bin() {{ echo "$1"; }}
prebuilt_tree() {{ echo "$1"; return 1; }}
uv_tool() {{ echo "uv:$1"; }}
for t in {tools}; do
  prebuilt_install "$t" >/dev/null 2>&1
  [ "$?" -eq 2 ] && echo "NONE $t"
done
prebuilt_install bat''', os_name)
                self.assertNotIn('NONE', p.stdout)
                url = p.stdout.splitlines()[-1]
                self.assertIn({'x86_64': 'x86_64', 'arm64': 'aarch64'}[arch], url)
                self.assertIn('apple-darwin' if os_name == 'macos' else 'linux', url)

    def test_cask_skips_app_installed_outside_homebrew(self):
        (self.home / 'Applications/kitty.app').mkdir(parents=True)
        p = self.common('brew() { echo "brew $*"; }; have() { true; }; '
                        'ensure_cask kitty kitty.app; echo rc=$?')
        self.assertEqual(p.stdout.strip(), 'rc=0', p.stderr)


@unittest.skipUnless(ZSH, 'zsh is required')
class ZshPackage(DotfilesFixture):
    def setUp(self):
        super().setUp()
        # pre_stow.sh dry-runs stow before moving ~/.zshenv; STOW_CONFLICT fails it.
        self.fake('stow', '''import os, sys
assert '-n' in sys.argv and '-R' in sys.argv and sys.argv[-1] == 'zsh'
if os.environ.get('STOW_CONFLICT'):
    raise SystemExit('WARNING! stowing zsh would cause conflicts')
''')

    def pre_stow(self):
        return self.run_command('bash', ROOT / 'zsh/pre_stow.sh')

    @property
    def profile(self):
        return self.home / '.local/.local_profile'

    def test_pre_stow_carries_legacy_startup_files_into_local_profile_once(self):
        self.write('.zshenv', 'export FROM_ZSHENV=1\n')
        self.write('.zprofile', 'export FROM_ZPROFILE=1\n')
        managed = self.write('managed-zshrc', 'export MANAGED=1\n')
        (self.home / '.zshrc').symlink_to(managed)
        for _ in range(2):
            p = self.pre_stow()
            self.assertEqual(p.returncode, 0, p.stderr)
            # Its config goes dead once ZDOTDIR is set, so say so.
            self.assertIn(f'{self.home}/.zshrc links to {managed}', p.stderr)
        profile = self.profile.read_text()
        self.assertEqual(profile.count('FROM_ZSHENV=1'), 1)
        self.assertEqual(profile.count('FROM_ZPROFILE=1'), 1)
        self.assertNotIn('MANAGED', profile)
        self.assertLess(profile.index('FROM_ZSHENV'), profile.index('FROM_ZPROFILE'))
        self.assertFalse((self.home / '.zshenv').exists())
        backups = list((self.home / '.local/state/dotfiles/backups').glob('zshenv.*/.zshenv'))
        self.assertEqual([b.read_text() for b in backups], ['export FROM_ZSHENV=1\n'])
        self.assertEqual((self.home / '.zprofile').read_text(), 'export FROM_ZPROFILE=1\n')
        self.assertTrue((self.home / '.zshrc').is_symlink())

    def test_migration_disables_lines_that_would_source_the_profile_again(self):
        self.write('.zshrc', '[[ -f "$HOME/.local/.local_profile" ]] && source "$HOME/.local/.local_profile"\n'
                   'source "$ZDOTDIR/.zshrc"\nsource ~/.zshrc.local\n')
        self.assertEqual(self.pre_stow().returncode, 0)
        lines = self.profile.read_text().splitlines()[2:5]
        self.assertTrue(lines[0].startswith('# disabled by zsh/pre_stow.sh'), lines)
        self.assertTrue(lines[1].startswith('# disabled by zsh/pre_stow.sh'), lines)
        self.assertEqual(lines[2], 'source ~/.zshrc.local')

    def test_pruned_profile_is_not_migrated_again(self):
        self.write('.zshrc', 'export LEGACY=1\n')
        self.assertEqual(self.pre_stow().returncode, 0)
        self.profile.write_text('# pruned\n')
        p = self.pre_stow()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.profile.read_text(), '# pruned\n')

    def test_profile_migrated_before_the_list_existed_is_recognised(self):
        self.write('.zshrc', 'export LEGACY=1\n')
        self.write('.local/.local_profile', f'# >>> migrated from {self.home}/.zshrc by dotfiles '
                   f'zsh/pre_stow.sh\nexport LEGACY=1\n# <<< end of {self.home}/.zshrc\n')
        self.assertEqual(self.pre_stow().returncode, 0)
        self.assertEqual(self.profile.read_text().count('LEGACY'), 1)
        self.profile.write_text('')
        self.assertEqual(self.pre_stow().returncode, 0)
        self.assertEqual(self.profile.read_text(), '')

    def test_stow_conflict_leaves_legacy_zshenv_in_place(self):
        self.write('.zshenv', 'export ZDOTDIR="$HOME/.config/zsh"\n')
        self.env['STOW_CONFLICT'] = '1'
        p = self.pre_stow()
        self.assertEqual(p.returncode, 1)
        self.assertIn('would cause conflicts', p.stderr)
        self.assertEqual((self.home / '.zshenv').read_text(), 'export ZDOTDIR="$HOME/.config/zsh"\n')
        self.assertFalse(self.profile.exists())
        self.assertEqual(list((self.home / '.local/state/dotfiles/backups').iterdir()), [])

    def test_pre_stow_drops_a_copy_of_the_repo_zshenv(self):
        shutil.copy(ROOT / 'zsh/.zshenv', self.home / '.zshenv')
        p = self.pre_stow()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse((self.home / '.zshenv').exists())
        self.assertFalse(self.profile.exists())
        self.assertEqual(list((self.home / '.local/state/dotfiles/backups').iterdir()), [])

    def brew_prefix(self):
        """The prefix .zshenv picks: the first with an executable bin/brew.
        ~/.linuxbrew is faked so that every host has one."""
        self.write('.linuxbrew/bin/brew', '#!/bin/sh\n').chmod(0o755)
        for prefix in ('/opt/homebrew', '/usr/local', '/home/linuxbrew/.linuxbrew', self.home / '.linuxbrew'):
            if os.access(f'{prefix}/bin/brew', os.X_OK):
                return f'{prefix}/bin'

    def test_child_shell_keeps_inherited_node_ahead_of_homebrew(self):
        brew = self.brew_prefix()
        p = self.run_command(ZSH, '-f', '-c', 'path=(/nvm/bin "$2" /usr/bin /bin); source "$1"; '
                             'print -rl -- $path', 'fixture', ROOT / 'zsh/.config/zsh/.zshenv', brew)
        self.assertEqual(p.returncode, 0, p.stderr)
        path = p.stdout.splitlines()
        self.assertEqual(path[:2], [str(self.home / '.local/scripts'), str(self.home / '.local/bin')])
        self.assertLess(path.index('/nvm/bin'), path.index(brew))

    def test_zprofile_restores_personal_bins_and_homebrew_after_path_helper(self):
        brew = self.brew_prefix()
        p = self.run_command(ZSH, '-f', '-c', 'source "$1"; path=(/usr/bin /bin $path); '
                             'source "$2"; print -rl -- $path', 'fixture',
                             ROOT / 'zsh/.config/zsh/.zshenv', ROOT / 'zsh/.config/zsh/.zprofile')
        self.assertEqual(p.returncode, 0, p.stderr)
        path = p.stdout.splitlines()
        self.assertEqual(path[:2], [str(self.home / '.local/scripts'), str(self.home / '.local/bin')])
        self.assertLess(path.index(brew), path.index('/usr/bin'))

    def test_local_profile_cannot_recurse_or_demote_personal_bins(self):
        rc = (ROOT / 'zsh/.config/zsh/.zshrc').read_text()
        self.write('profile-block.zsh', rc[rc.index('# Guarded because migrated'):])
        # A migrated legacy file that sources .zshrc again, then brew shellenv.
        self.write('.local/.local_profile', 'print sourced\nsource ~/profile-block.zsh\n'
                   'path=(/brew/bin $path)\n')
        p = self.run_command(ZSH, '-f', '-c', 'source "$1"; print -rl -- $path[1,3]',
                             'fixture', self.home / 'profile-block.zsh')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout.splitlines(), ['sourced', str(self.home / '.local/scripts'),
                                                 str(self.home / '.local/bin'), '/brew/bin'])

    def test_default_node_is_on_path_for_child_processes(self):
        rc = (ROOT / 'zsh/.config/zsh/.zshrc').read_text()
        block = rc[rc.index('_nvm_default_bin() {'):rc.index('unfunction _nvm_default_bin')]
        self.write('nvm-path.zsh', 'NVM_DIR="$HOME/.nvm"\n' + block)
        for version in ('20.9.0', '20.11.1', '22.3.0', '22.4.0-nightly20240601'):
            self.write(f'.nvm/versions/node/v{version}/bin/node', '#!/bin/sh\n').chmod(0o755)
        self.write('.nvm/alias/lts/*', 'lts/jod\n')
        self.write('.nvm/alias/lts/jod', 'v22.3.0\n')
        for alias, expected in [('lts/*', 'v22.3.0'), ('20', 'v20.11.1'), ('v20.9.0', 'v20.9.0'),
                                ('node', 'v22.3.0'), ('22', 'v22.3.0'), ('lts/iron', None),
                                ('system', None), ('', None), (None, None)]:
            with self.subTest(alias=alias):
                default = self.home / '.nvm/alias/default'
                if alias is None:   # no default: nvm activates nothing
                    default.unlink(missing_ok=True)
                else:
                    self.write('.nvm/alias/default', alias + '\n')
                p = self.run_command(ZSH, '-f', '-c', 'source "$1"; print -r -- "${path[1]}"',
                                     'fixture', self.home / 'nvm-path.zsh')
                self.assertEqual(p.returncode, 0, p.stderr)
                first = p.stdout.strip()
                if expected:
                    self.assertEqual(first, str(self.home / f'.nvm/versions/node/{expected}/bin'))
                else:
                    self.assertNotIn('.nvm', first)

    def test_missing_tools_leave_core_commands_alone(self):
        # Only the fake bin: a host with eza or rg in /usr/bin must not count.
        self.env['PATH'] = str(self.bin)
        p = self.run_command(ZSH, '-f', '-c', 'compdef() { :; }; source "$1"; alias ls grep; '
                             'source "$2"; print ok', 'fixture',
                             ROOT / 'zsh/.config/zsh/aliases.zsh', ROOT / 'zsh/.config/zsh/prompt.zsh')
        self.assertEqual(p.stdout.splitlines(), ['ok'], p.stderr)
        self.fake('eza', '')
        self.fake('rg', '')
        p = self.run_command(ZSH, '-f', '-c', 'compdef() { :; }; source "$1"; alias ls grep',
                             'fixture', ROOT / 'zsh/.config/zsh/aliases.zsh')
        self.assertEqual(p.stdout.splitlines(), ["ls='eza --icons'", "grep='rg --color=auto'"])


class Llvm(DotfilesFixture):
    def test_dead_keg_link_is_replaced_and_foreign_files_kept(self):
        bin_dir = self.home / '.local/bin'
        bin_dir.mkdir(parents=True)
        (bin_dir / 'clangd').symlink_to('/nonexistent/opt/llvm/bin/clangd')
        (bin_dir / 'clang-format').symlink_to('/nonexistent/elsewhere/clang-format')
        # Shadow tools that do run, such as the Command Line Tools' /usr/bin/clangd.
        for name in ('clangd', 'clang-format'):
            self.fake(name, 'raise SystemExit(1)')
        self.env['DOTFILES_COMMON_SH'] = '1'
        p = self.run_command('bash', '-c', r'''
source "$1"
_llvm_root() { return 1; }
brew_can_pour() { return 1; }
warn() { echo "$*" >&2; }
uv_tool() { printf '#!/bin/sh\nexit 0\n' > "$HOME/.local/bin/$1"; chmod +x "$HOME/.local/bin/$1"; echo "uv $1"; }
ensure_llvm clangd clang-format; echo "rc=$?"
''', 'fixture', ROOT / 'clangd/install.sh')
        self.assertEqual(p.stdout.splitlines(), ['uv clangd', 'rc=0'], p.stderr)
        self.assertFalse((bin_dir / 'clangd').is_symlink())
        self.assertEqual(os.readlink(bin_dir / 'clang-format'), '/nonexistent/elsewhere/clang-format')
        self.assertIn('preserving existing', p.stderr)


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
ensure_cask() { return 0; }
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
