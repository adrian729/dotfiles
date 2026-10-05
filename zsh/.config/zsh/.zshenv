# ---------- XDG base directories ----------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# ---------- Locale ----------
: "${LANG:=en_US.UTF-8}"
export LANG

# ---------- Editor ----------
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR="vim"
else
  export EDITOR="nvim"
fi
export VISUAL="$EDITOR"

# ---------- Pager ----------
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="bat -l man -p"
elif command -v batcat >/dev/null 2>&1; then
  export MANPAGER="batcat -l man -p"
fi

# ---------- GPG ----------
export GPG_TTY=$(tty)

# ---------- Starship ----------
export STARSHIP_CONFIG="$ZDOTDIR/starship.toml"

# ---------- eza ----------
export EZA_CONFIG_DIR="$XDG_CONFIG_HOME/eza"

# ---------- Rust/Cargo ----------
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# ---------- Ollama ----------
[[ -f "$HOME/.config/ollama/ollama.env" ]] && . "$HOME/.config/ollama/ollama.env"

# ---------- Claude ----------
[[ -f "$HOME/.claude/claude.env" ]] && . "$HOME/.claude/claude.env"

# ---------- PATH ----------
# Personal bins first, then Homebrew, then the system. A function because on
# macOS /etc/zprofile runs path_helper after this file and moves the system
# directories back in front for login shells; .zprofile re-applies it with
# --force. Without it, a Homebrew already on PATH keeps its place, so a child
# shell does not push Homebrew back ahead of the nvm node its parent chose.
typeset -U path
_dotfiles_path() {
  local p brew_prefix
  for p in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew "$HOME/.linuxbrew"; do
    [[ -x $p/bin/brew ]] && { brew_prefix=$p; break; }
  done
  local -a brew_dirs=(${brew_prefix:+$brew_prefix/bin} ${brew_prefix:+$brew_prefix/sbin})
  [[ $1 == --force ]] || brew_dirs=(${brew_dirs:|path})
  path=("$HOME/.local/scripts" "$HOME/.local/bin" "$HOME/.opencode/bin" $brew_dirs $path)
}
_dotfiles_path
