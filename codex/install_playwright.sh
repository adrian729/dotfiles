#!/bin/bash

. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null
ensure_node || { warn "Playwright requires Node.js 18+ and npm"; exit 1; }

if ! have playwright-cli; then
	npm install -g @playwright/cli@latest || { warn "Playwright CLI installation failed"; exit 1; }
fi

# Keep the upstream skill outside git, and preserve any existing local copy.
skill_target="${CODEX_HOME:-$HOME/.codex}/skills/playwright-cli"
if [ ! -e "$skill_target" ] && [ ! -L "$skill_target" ]; then
	npm_root=$(npm root -g) || exit 1
	skill_source="$npm_root/@playwright/cli/skills/playwright-cli"
	if [ ! -f "$skill_source/SKILL.md" ]; then
		warn "Playwright skill missing from the global npm package; reinstall @playwright/cli"
		exit 1
	fi
	mkdir -p "$(dirname "$skill_target")" && cp -R "$skill_source" "$skill_target" || exit 1
	info "Installed Playwright skill to $skill_target"
fi

# Select the downloaded browser so plain `playwright-cli open` works without
# requiring a system Chrome installation. Project configs can override this.
browser_config="$HOME/.playwright/cli.config.json"
if [ ! -e "$browser_config" ] && [ ! -L "$browser_config" ]; then
	mkdir -p "$(dirname "$browser_config")" || exit 1
	printf '%s\n' '{"browser":{"browserName":"chromium","launchOptions":{"channel":"chromium"}}}' > "$browser_config" || exit 1
fi

# Browser downloads stay in Playwright's user cache. Do not invoke a distro
# package manager here; Playwright reports missing OS libraries if needed.
playwright-cli install-browser chromium --no-shell || {
	warn "Playwright browser installation failed; retry: bash codex/install_playwright.sh"
	exit 1
}
info "Playwright CLI and Chromium are installed; use the playwright-cli skill for browser tasks"
