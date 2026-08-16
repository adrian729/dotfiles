# =========================================================
# fzf
# =========================================================

# Debian/Ubuntu package fd as `fdfind` (name clash with an unrelated fd), so
# resolve the binary rather than hardcoding one name.
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden'
elif (( $+commands[fdfind] )); then
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden'
else
  export FZF_DEFAULT_COMMAND='find . -type f'
fi

# Ctrl-T uses fd
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# UI opts are per-widget, never global: exported FZF_DEFAULT_OPTS leaks into
# non-interactive fzf calls (tmux popups/neww scripts) via the tmux server env.
_FZF_UI_OPTS="--height=60% --layout=reverse --border=rounded --prompt='  ' --pointer='  ' --preview-window=right:65%:wrap:border-left --bind='ctrl-n:down,ctrl-p:up'"

if (( $+commands[bat] )); then
  export _FZF_PREVIEW_CMD='bat --color=always --style=plain,numbers --line-range=:500 {}'
elif (( $+commands[batcat] )); then
  export _FZF_PREVIEW_CMD='batcat --color=always --style=plain,numbers --line-range=:500 {}'
else
  export _FZF_PREVIEW_CMD='head -500 {}'
fi
export FZF_CTRL_T_OPTS="$_FZF_UI_OPTS --preview '$_FZF_PREVIEW_CMD'"
export FZF_CTRL_R_OPTS="$_FZF_UI_OPTS"
export FZF_ALT_C_OPTS="$_FZF_UI_OPTS"

# Ctrl+F: file picker excluding hidden files
_fzf_file_no_hidden() {
  local cmd result
  cmd="${FZF_DEFAULT_COMMAND/--hidden /}"
  result=$(eval "${cmd:-find . -type f}" | fzf "${(@Qz)_FZF_UI_OPTS}" --preview "$_FZF_PREVIEW_CMD") \
    && LBUFFER+="$result"  # LBUFFER is the text left of the cursor
  zle reset-prompt
}
zle -N _fzf_file_no_hidden
