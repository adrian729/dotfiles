# Better ls. Only when eza exists: an alias to a missing command would break
# plain `ls` on a machine where the installer could not provide it.
if (( $+commands[eza] )); then
  alias ls='eza --icons'

  # Detailed listing
  alias ll='eza -lh --icons --git'

  # Detailed listing including hidden files
  alias la='eza -lah --icons --git'

  # Tree view
  alias tree='eza --tree --icons'

  # Reuse ls completions for eza (avoids defining a separate completion function)
  compdef eza=ls
fi

# Better cat. Debian/Ubuntu package bat as `batcat` to avoid a name clash, so
# fall back to that name before giving up and leaving plain cat alone.
if (( $+commands[bat] )); then
  alias cat='bat'
elif (( $+commands[batcat] )); then
  alias cat='batcat'
fi

# =========================================================
# Core utilities
# =========================================================

(( $+commands[rg] )) && alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'

# =========================================================
# Navigation
# =========================================================

alias -- -='cd -'  # -- prevents - being parsed as a flag; cd - jumps to previous directory

lf() {
    local tmpdir dir rc
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/lf.XXXXXX") || return
    {
        LF_NO_CD_FILE="$tmpdir/no-cd" command lf -last-dir-path="$tmpdir/last-dir" "$@"
        rc=$?
        if (( rc == 0 )) && [[ ! -e "$tmpdir/no-cd" && -s "$tmpdir/last-dir" ]]; then
            dir=$(<"$tmpdir/last-dir")
            if [[ -d "$dir" ]]; then
                builtin cd -- "$dir" || rc=$?
            fi
        fi
    } always {
        command rm -rf -- "$tmpdir"
    }
    return "$rc"
}

# =========================================================
# Git
# =========================================================

alias glog='PAGER="less -F -X" git log'                              # -F quit if one screen, -X no clear on exit
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
# Resolve the checkout through the stowed symlink, including clone paths with spaces.
typeset _dotfiles_repo="${${(%):-%x}:A:h:h:h:h}"
alias dotfiles="git -C ${(q)_dotfiles_repo}"
unset _dotfiles_repo

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
