#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null

# zsh itself comes from the OS, never from brew: macOS ships it as the default
# shell, and on Linux a login shell living under /home/linuxbrew is a footgun —
# if that tree is missing or unmounted the account can no longer log in.
if ! have zsh; then
	if is_linux; then
		info "Installing zsh..."
		pkg_install zsh || warn "zsh not installed — this whole package will be inert"
	else
		warn "zsh missing on macOS, which is unexpected — install it manually"
	fi
fi

# One at a time, so each tool can take its own route: a bottle, its release
# build, or (eza on a Mac without either) cargo.
for spec in bat eza fd fzf jq rg:ripgrep starship zoxide; do
	ensure_cmd "${spec%%:*}" "${spec#*:}" || warn "${spec%%:*} unavailable — the shell skips what needs it"
done

# claude-agent-acp needs node 22+. Owned by the shared helper so
# claude/install.sh, which runs earlier, gets the same nvm node.
ensure_node 22 || warn "node/npm unavailable — nvm-backed tooling will not work"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
mkdir -p "$state_dir"
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# .zshrc keeps history under XDG_STATE_HOME; start it from the old file so
# history search survives the move.
if [ ! -s "$state_dir/history" ] && [ -s "$HOME/.zsh_history" ]; then
	cp "$HOME/.zsh_history" "$state_dir/history" && chmod 600 "$state_dir/history"
fi

# starship's prompt, `eza --icons`, lf's icons and the tmux status bar are all
# Nerd Font glyphs — without a patched font every one of them renders as tofu.
ensure_nerd_font

# nvim's clipboard=unnamedplus and tmux's copy binding both need a system
# clipboard bridge, which Linux does not have out of the box.
ensure_clipboard

# Offer to make zsh the login shell, for the one case that needs it: a fresh
# Kubuntu account is on bash, which leaves this entire package unused. macOS
# already defaults to zsh and must never be prompted here.
#
# The test asks whether the login shell is a zsh *by name*. Comparing paths
# instead is wrong: brew_shellenv above puts the brew prefix first on PATH, so
# `command -v zsh` resolves to a Homebrew zsh whenever one is installed, and
# comparing that against a perfectly good /bin/zsh reads as "not zsh yet" —
# offering to move the login shell into the brew prefix. If that prefix goes
# missing, or `brew uninstall zsh` removes it, the account can no longer log in.
current_shell=""
if is_macos; then
	current_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')
else
	current_shell=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
fi
[ -n "$current_shell" ] || current_shell="${SHELL:-}"

# Only offer when the current shell is known AND is not already a zsh. An
# unknown shell means neither the user database nor $SHELL answered, and
# prompting on that guess is how the wrong shell gets set.
if have zsh && [ -n "$current_shell" ] && [ "${current_shell##*/}" != zsh ]; then
	# An OS-owned zsh only. If the only zsh on this machine is Homebrew's, say
	# so and change nothing: making a brew binary the login shell means losing
	# shell access if that prefix ever disappears.
	zsh_path=""
	for candidate in /bin/zsh /usr/bin/zsh; do
		[ -x "$candidate" ] && {
			zsh_path="$candidate"
			break
		}
	done
	if [ -z "$zsh_path" ]; then
		warn "only a non-system zsh ($(command -v zsh)) is available — not offering it as a login shell."
		warn "  Install the distro's zsh package first, then run: chsh -s /usr/bin/zsh"
	elif confirm "Login shell is $current_shell. Make zsh ($zsh_path) your login shell (chsh)?"; then
		grep -qxF "$zsh_path" /etc/shells 2>/dev/null ||
			echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
		chsh -s "$zsh_path" || warn "chsh failed — run it yourself: chsh -s $zsh_path"
	else
		echo "Login shell left as $current_shell — switch later with: chsh -s $zsh_path"
	fi
fi
