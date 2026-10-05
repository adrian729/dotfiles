# Uses:
#   Plugins:      fast-syntax-highlighting, zsh-autosuggestions,
#                 zsh-history-substring-search, zsh-vi-mode
#   Prompt:       starship
#   Navigation:   zoxide, fzf, fd
#   CLI tools:    eza, bat, nvim, ripgrep
#   Node:         nvm

# =========================================================
# History
# =========================================================

HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS

# =========================================================
# Shell behaviour
# =========================================================

setopt AUTOCD
setopt NOBEEP
setopt NUMERIC_GLOB_SORT  # sort file10 after file9, not after file1

# =========================================================
# Smart directory navigation & lf
# =========================================================

(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# =========================================================
# Completion
# =========================================================

# Load completion system
autoload -Uz compinit

compinit -C -d "$XDG_CACHE_HOME/zsh/zcompdump"

# Enable interactive completion menu selection
zstyle ':completion:*' menu select

# Make completion case-insensitive
# Example: "doc" can complete to "Documents"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # lowercase input matches upper and lower

# =========================================================
# Fuzzy finder
# =========================================================

# fzf 0.48+ prints its own shell integration, wherever it was installed from
# (Homebrew, a release build, a recent distro package). Older distro packages
# ship the scripts instead.
if (( $+commands[fzf] )) && fzf --zsh &>/dev/null; then
  source <(fzf --zsh)
else
  for _fzf_dir in /usr/share/fzf /usr/share/doc/fzf/examples; do
    if [[ -f $_fzf_dir/key-bindings.zsh ]]; then
      source "$_fzf_dir/key-bindings.zsh"
      [[ -f $_fzf_dir/completion.zsh ]] && source "$_fzf_dir/completion.zsh"
      break
    fi
  done
  unset _fzf_dir
fi

# =========================================================
# Modular Config Files
# =========================================================

# fzf configuration
source "$ZDOTDIR/fzf.zsh"

# Aliases
source "$ZDOTDIR/aliases.zsh"

# Custom keybindings
source "$ZDOTDIR/bindings.zsh"

# Plugins and plugin manager
source "$ZDOTDIR/plugins.zsh"

# Prompt/theme
source "$ZDOTDIR/prompt.zsh"


# =========================================================
# Node / NVM
# =========================================================

export NVM_DIR="$HOME/.nvm"

_load_nvm() {
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
}
for _nvm_cmd in nvm node npm npx; do
  eval "${_nvm_cmd}() { unset -f nvm node npm npx; _load_nvm; ${_nvm_cmd} \"\$@\"; }"
done
unset _nvm_cmd

# The shims above only exist inside this shell, so programs it starts (nvim's
# ACP adapter running claude-agent-acp, playwright-cli) would not find
# node-based CLIs. Put the default node's bin directory on PATH up front,
# resolving nvm's alias files by hand instead of sourcing nvm.sh.
_nvm_default_bin() {
  local v=default hops=0 vers=$NVM_DIR/versions/node
  local -a dirs
  while [[ -f $NVM_DIR/alias/$v ]] && (( hops++ < 5 )); do
    v=$(<"$NVM_DIR/alias/$v")
  done
  case $v in
    node|stable) v= ;;
    # No or an empty default alias (nvm then activates nothing), a loop, or
    # an LTS alias whose target is not installed.
    ''|default|lts/*) return 1 ;;
  esac
  v=${v#v}
  if [[ -n $v && -d $vers/v$v ]]; then
    dirs=("$vers/v$v")
  else
    # Highest matching release; nightly and rc builds carry a "-" suffix.
    dirs=($vers/v${v:+$v.}*(N/nOn))
    dirs=(${dirs:#*-*})
  fi
  (( $#dirs )) && [[ -x $dirs[1]/bin/node ]] && print -r -- "$dirs[1]/bin"
}
if _nvm_bin=$(_nvm_default_bin); then
  path=("$_nvm_bin" $path)
fi
unset _nvm_bin
unfunction _nvm_default_bin

# =========================================================
# Local overrides
# =========================================================

# Guarded because migrated legacy startup files (zsh/pre_stow.sh) may source
# this .zshrc, or the profile itself, again.
if [[ -f "$HOME/.local/.local_profile" && -z $_dotfiles_in_local_profile ]]; then
  _dotfiles_in_local_profile=1
  source "$HOME/.local/.local_profile"
  unset _dotfiles_in_local_profile
fi
# Migrated lines such as `eval "$(brew shellenv)"` put Homebrew back in front;
# the personal bins, where release builds of the tools land, stay first.
path=("$HOME/.local/scripts" "$HOME/.local/bin" $path)
