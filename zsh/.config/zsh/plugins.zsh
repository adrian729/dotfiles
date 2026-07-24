# =========================================================
# Plugins
# =========================================================

ZPLUGINDIR="${ZDOTDIR:-$HOME/.config/zsh}/plugins"

_zplugin_load() {
  # Clone into a sibling tmp dir and atomic-move on success: an interrupted
  # clone (Ctrl-C, network drop) leaves an orphan tmp dir but never a broken
  # real path that future shells would source as if it were a valid plugin.
  local plugin_path="${ZPLUGINDIR}/${2}" tmp="${ZPLUGINDIR}/.${2}.tmp.$$"
  if [[ ! -d "$plugin_path" ]]; then
    mkdir -p "$ZPLUGINDIR"
    echo "Installing ${2}..."
    if git clone --depth=1 "https://github.com/${1}/${2}" "$tmp"; then
      mv "$tmp" "$plugin_path"
    else
      rm -rf "$tmp"
      echo "ERROR: failed to install ${2}" >&2
      return 1
    fi
  fi
  source "${plugin_path}/${2}.plugin.zsh"
}

zplugin-update() {
  local dir
  for dir in "${ZPLUGINDIR}"/*/; do
    echo "Updating ${dir:t}..."
    git -C "$dir" pull --ff-only
  done
}

_zplugin_load zsh-users zsh-autosuggestions
_zplugin_load zsh-users zsh-history-substring-search
_zplugin_load jeffreytse zsh-vi-mode
_zplugin_load zdharma-continuum fast-syntax-highlighting
