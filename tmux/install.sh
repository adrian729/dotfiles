#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

ensure_cmd tmux
ensure_cmd fzf
ensure_cmd bc

# The tmux prefix is C-Space, which macOS takes by default for "Select the
# previous input source" (hotkey 60) once a second keyboard layout exists, so
# the key never reaches the terminal. Ctrl+Option+Space (61) still switches.
# The running session picks this up after logging out and back in.
if is_macos; then
	defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
		'{ enabled = 0; value = { parameters = (32, 49, 262144); type = standard; }; }' &&
		/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u \
			>/dev/null 2>&1 ||
		warn "could not free Ctrl+Space from macOS input-source switching"
fi

# tmux.conf binds copy-mode `y` to ~/.local/scripts/tmux-clipboard, which needs
# one of pbcopy/wl-copy/xclip/xsel to exist or copying silently does nothing.
ensure_clipboard

if [ ! -d ~/.tmux/plugins/tpm ]; then
	echo "Cloning TPM..."
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# install_plugins only clones missing plugins and never moves an existing one.
# A catppuccin clone older than the version tmux.conf pins does not know the
# options it uses, and renders the status bar as raw style text, so move it.
ctp_dir="$HOME/.tmux/plugins/tmux"
ctp_ref=$(grep -o 'catppuccin/tmux#[^[:space:]\\]*' "$(dirname "$0")/.config/tmux/tmux.conf")
ctp_ref=${ctp_ref#*#}
if [ -n "$ctp_ref" ] && [ -d "$ctp_dir/.git" ] &&
	[ "$(git -C "$ctp_dir" rev-parse HEAD)" != \
		"$(git -C "$ctp_dir" rev-parse -q --verify "refs/tags/$ctp_ref^{commit}")" ]; then
	echo "Moving catppuccin to $ctp_ref..."
	git -C "$ctp_dir" fetch -q origin tag "$ctp_ref" && git -C "$ctp_dir" checkout -q "$ctp_ref" ||
		warn "could not move catppuccin to $ctp_ref — delete $ctp_dir and re-run"
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
