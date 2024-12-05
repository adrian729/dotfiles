#########
# UTILS #
#########

# OS
IS_MAC=false
IS_LINUX=false
case "$(uname -s)" in
  Darwin*)
    IS_MAC=true
    ;;
  Linux*)
    IS_LINUX=true
    ;;
esac

# PATH
prepend_path() {
  if [ -d "$1" ]; then
    export PATH="$1:$PATH"
  fi
}

append_path() {
  if [ -d "$1" ]; then
    export PATH="$PATH:$1"
  fi
}

prepend_path_file() {
  if [ -f "$1" ]; then
    export PATH="$1:$PATH"
  fi
}
# Profiling
timezsh() {
  shell=${1-$SHELL}
  for i in $(seq 1 10); do /usr/bin/time $shell -i -c exit; done
}

##########
# CONFIG #
##########

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# history
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
HISTSIZE=1000
HISTFILESIZE=5000
SAVEHIST=5000

################
# PATH & TOOLS #
################

# If you come from bash you might have to change your $PATH.
prepend_path $HOME/bin
prepend_path /usr/local/bin
prepend_path $HOME/.local/bin

# homebrew
prepend_path /opt/homebrew/bin
prepend_path /home/linuxbrew/.linuxbrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# homebrew end

# autojump
[ -f "$(brew --prefix)/etc/profile.d/autojump.sh" ] && . "$(brew --prefix)/etc/profile.d/autojump.sh"
# autojump end

# luarocks - https://luarocks.org/ for how to install, TODO: some script to install all config reqs
prepend_path_file /usr/bin/luarocks
prepend_path_file /usr/local/bin/luarocks
prepend_path /usr/local/etc/luarocks
prepend_path /usr/local/share/lua
prepend_path /usr/local/share/lua/5.4
prepend_path /usr/local/lib/lua/5.4
# luarocks end

# nvm
# export NVM_DIR="$HOME/.nvm"
#export NVM_LAZY_LOAD=true
#export NVM_COMPLETION=true
#[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"                   # This loads nvm
#[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
# nvm end

# pnpm
#if [[ "$IS_MAC" == 'true' ]]; then
#  export PNPM_HOME="~/Library/pnpm"
#fi
#if [[ "$IS_LINUX" == 'true' ]]; then
#  export PNPM_HOME="~/.local/share/pnpm"
#fi
#case ":$PATH:" in
#    *":$PNPM_HOME:"*) ;;
#    *) export PATH="$PNPM_HOME:$PATH" ;;
#esac
# pnpm end

# fzf
source <(fzf --zsh)
# fzf end

#######################
# OH-MY-ZSH & PLUGINS #
#######################
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="half-life"
ZSH_CUSTOM="$HOME/.config/zsh"
plugins=(
    git
    autojump
    zsh-syntax-highlighting
    zsh-autosuggestions
    poetry
)

source $ZSH/oh-my-zsh.sh

zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' frequency 7 

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#808080,bg=#111111,italics,underline"
HYPHEN_INSENSITIVE="true"
if [ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [ -f "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
# zsh-autosuggestions end

####################
# ADD LOCAL CONFIG #
####################
if [ -f $HOME/local/.local_profile ]; then
    . $HOME/local/.local_profile 
fi

