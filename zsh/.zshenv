# Initial config to setup envs for .config and zsh

if [[ -z "$XDG_CONFIG_HOME" ]] then
    export XDG_CONFIG_HOME="$HOME/.config" 
fi

if [[ -z "$XDG_STATE_HOME" ]] then
    export XDG_STATE_HOME="$HOME/.local/state"
fi

if [[ -d "$XDG_CONFIG_HOME/zsh" ]] then
    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi

# zsh only auto-reads .zshenv once, before ZDOTDIR above takes effect, so the
# rest of the env setup living under $ZDOTDIR must be pulled in explicitly.
[[ -n "$ZDOTDIR" && -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"

