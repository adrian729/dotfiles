# ---------- XDG base directories ----------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

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

# ---------- Rust/Cargo ----------
. "$HOME/.cargo/env"

# ---------- Ollama ----------
[[ -f "$HOME/.config/ollama/ollama.env" ]] && . "$HOME/.config/ollama/ollama.env"

# ---------- PATH ----------
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/scripts:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"
[[ -d /opt/homebrew/bin ]] && export PATH="/opt/homebrew/bin:$PATH"
