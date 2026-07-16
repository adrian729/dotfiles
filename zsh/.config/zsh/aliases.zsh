# Better ls
alias ls='eza --icons'

# Detailed listing
alias ll='eza -lh --icons --git'

# Detailed listing including hidden files
alias la='eza -lah --icons --git'

# Tree view
alias tree='eza --tree --icons'

# Reuse ls completions for eza (avoids defining a separate completion function)
compdef eza=ls

# Better cat
alias cat='bat'

# =========================================================
# Core utilities
# =========================================================

alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'

# =========================================================
# Navigation
# =========================================================

alias -- -='cd -'  # -- prevents - being parsed as a flag; cd - jumps to previous directory

lf() {
    local no_cd_flag="/tmp/lf-no-cd-$(id -u)"
    tmp=$(mktemp)
    rm -f "$no_cd_flag"
    command lf -last-dir-path="$tmp" "$@"
    if [ -f "$no_cd_flag" ]; then
        rm -f "$no_cd_flag"
    elif [ -f "$tmp" ]; then
        dir=$(cat "$tmp")
        [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
    fi
    rm -f "$tmp"
}

# =========================================================
# Git
# =========================================================

alias glog='PAGER="less -F -X" git log'                              # -F quit if one screen, -X no clear on exit
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# =========================================================
# Video
# =========================================================

alias stream='mpv av://v4l2:/dev/video4 --fullscreen --demuxer-lavf-o=input_format=mjpeg,framerate=30 --profile=low-latency --untimed'

# =========================================================
# Network
# =========================================================

nc_tcp_write() {
  local msg="${1:-Do we have a test?}"
  local port="${2:-42069}"
  printf '%s' "$msg" | nc -c -w 1 127.0.0.1 "$port"
}

nc_udp_listen() {
  local port="${1:-42069}"
  nc -u -l "$port"
}
