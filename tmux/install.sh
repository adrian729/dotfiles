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
# remembering to hit prefix+I. install_plugins is idempotent and offline-safe.
echo "Installing tmux plugins via TPM..."
~/.tmux/plugins/tpm/bin/install_plugins
