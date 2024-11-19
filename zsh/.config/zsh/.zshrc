if test -n "$KITTY_INSTALLATION_DIR"; then
    export KITTY_SHELL_INTEGRATION="enabled"
    autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
    kitty-integration
    unfunction kitty-integration
fi

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

# If you come from bash you might have to change your $PATH.
prepend_path $HOME/bin:$HOME/.local/bin:/usr/local/bin

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="half-life"

# CASE_SENSITIVE="true"

# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

ENABLE_CORRECTION="true"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#808080,bg=#111111,italics,underline"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

ZSH_CUSTOM="$HOME/.config/zsh"

source $ZSH/oh-my-zsh.sh

plugins=(
  git
  autojump
  zsh-syntax-highlighting
  zsh-autosuggestions
  poetry
)

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
export LANG=en_US.UTF-8

#########
# TOOLS #
#########
# eval "$(fzf --zsh)"
source <(fzf --zsh)

#######
# NVM #
#######
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# export MANPATH="/usr/local/man:$MANPATH"

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
export EDITOR='vim'
else
export EDITOR='nvim'
fi

prepend_path /opt/homebrew/bin
prepend_path /home/linuxbrew/.linuxbrew

########### TO REMOVE AND ADD SOMEHOW LOCAL CONFIGS ###
# TODO: filter path and check how to add some local configs not in dotfiles
prepend_path /home/adrian/.local/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/home/adrian/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin:/home/adrian/daedalus/tools/linux_devbox:/home/adrian/.fzf/bin:/home/adrian/daedalus/tools/linux_devbox
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# TODO: this should go into local bash/zsh profile
export PATH=$PATH:~/daedalus/tools/linux_devbox
########### EBD TO REMOVE AND ADD SOMEHOW LOCAL CONFIGS ###

if [ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [ -f "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
