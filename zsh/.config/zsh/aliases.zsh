# Custom aliases

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# TODO: check if there is something to stash or not do stash pop
alias gitstashpull='git stash && git pull && git stash pop'

nc_tcp_write() {
  msg="Do we have a test?"
  if [ -n "$1" ]; then
    msg="$1"
  fi

  port=42069
  if [ -n "$2" ]; then
    port="$2"
  fi

  printf "$msg" | nc -c -w 1 127.0.0.1 "$port"
}

nc_udp_listen() {
  port=42069
  if [ -n "$1" ]; then
    port="$1"
  fi

  nc -u -l "$port"
}

