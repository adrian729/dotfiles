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

