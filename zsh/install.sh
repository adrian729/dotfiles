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

MISSING=()
command -v bat &>/dev/null || MISSING+=(bat)
command -v eza &>/dev/null || MISSING+=(eza)
command -v fd &>/dev/null || MISSING+=(fd)
command -v fzf &>/dev/null || MISSING+=(fzf)
command -v jq &>/dev/null || MISSING+=(jq)
command -v rg &>/dev/null || MISSING+=(ripgrep)
command -v starship &>/dev/null || MISSING+=(starship)
command -v zoxide &>/dev/null || MISSING+=(zoxide)
if [ ${#MISSING[@]} -gt 0 ]; then
	if have brew; then
		brew install "${MISSING[@]}"
	else
		warn "brew unavailable — missing: ${MISSING[*]}"
	fi
fi

# fzf's key-binding installer lives inside the brew keg. An fzf that came from
# apt has no such script (its bindings ship in /usr/share/doc/fzf/examples, and
# .zshrc already sources that path), so only run this for a brew fzf.
if command -v fzf &>/dev/null && [ ! -f ~/.fzf.zsh ] && have brew &&
	fzf_prefix=$(brew --prefix fzf 2>/dev/null) && [ -x "$fzf_prefix/install" ]; then
	echo "Installing fzf key bindings and completion..."
	"$fzf_prefix"/install --key-bindings --completion --no-fish --no-update-rc
fi

# nvm + node. Owned by the shared helper so claude/install.sh — which runs
# earlier and needs npm for claude-agent-acp — gets the same node rather than
# racing a second one onto PATH.
ensure_node || warn "node/npm unavailable — nvm-backed tooling will not work"

mkdir -p ~/.local/state/zsh
mkdir -p ~/.cache/zsh

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
