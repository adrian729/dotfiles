#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

ensure_cmd tmux
ensure_cmd fzf
# tmux-ollama-status and tmux-usage-status both format RSS with bc, which macOS
# ships but a Debian install is not guaranteed to have.
ensure_cmd bc

# tmux.conf binds copy-mode `y` to ~/.local/scripts/tmux-clipboard, which needs
# one of pbcopy/wl-copy/xclip/xsel to exist or copying silently does nothing.
ensure_clipboard

if [ ! -d ~/.tmux/plugins/tpm ]; then
	echo "Cloning TPM..."
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# tmux.conf's @tpm_plugins are fetched by prefix+I normally; do it here so a
# fresh machine (or an update) gets catppuccin/cpu/battery/etc. without anyone
# remembering to hit prefix+I. install_plugins is idempotent and offline-safe,
# so retrying it is safe too.
echo "Installing tmux plugins via TPM..."
tpm_install_output="$(~/.tmux/plugins/tpm/bin/install_plugins 2>&1)"
echo "$tpm_install_output"

# GitHub's git-smart-HTTP backend can intermittently 401 the git-upload-pack
# POST over a reused HTTP/2 connection ("Repository not found" on a public
# repo) even though the preceding info/refs GET succeeded. A plain retry
# doesn't help; forcing HTTP/1.1 does. Retry once, scoped to this one
# subprocess via env vars so it never touches the user's ~/.gitconfig.
if echo "$tpm_install_output" | grep -q "download fail"; then
	echo "Retrying failed tmux plugin download(s) over HTTP/1.1..."
	GIT_CONFIG_COUNT=1 \
		GIT_CONFIG_KEY_0="http.https://github.com/.version" \
		GIT_CONFIG_VALUE_0="HTTP/1.1" \
		~/.tmux/plugins/tpm/bin/install_plugins
fi
