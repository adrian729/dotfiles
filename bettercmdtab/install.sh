#!/bin/bash

[[ "$OSTYPE" == "darwin"* ]] || { echo "bettercmdtab is macOS-only, skipping"; exit 0; }

command -v bettercmdtab &>/dev/null || brew install --cask bettercmdtab

# Copy config.json as a regular file (not symlink), so BetterCmdTab can
# modify it freely (live two-way sync) without dirtying the dotfiles repo.
# Re-run install.sh to reset from the repo version.
config_target="$HOME/.config/bettercmdtab/config.json"
mkdir -p "$(dirname "$config_target")"
tmp_config=$(mktemp "$config_target.XXXXXX")
if /bin/cp "$(dirname "$0")/.config/bettercmdtab/config.json" "$tmp_config"; then
    chmod 644 "$tmp_config"
    mv "$tmp_config" "$config_target"
else
    rm -f "$tmp_config"
    echo "bettercmdtab/install.sh: failed to copy config.json — leaving existing $config_target untouched" >&2
fi

# Write settings directly to UserDefaults (more reliable than config file sync).
# The app may not read config.json on first launch; defaults write ensures
# settings are applied immediately.
domain="pro.bettercmdtab.BetterCmdTab"

# Layout & display
defaults write "$domain" Switcher.layoutMode -string "list"
defaults write "$domain" Switcher.displayMode -string "activeWindow"
defaults write "$domain" Switcher.sortOrder -string "mruWindows"
defaults write "$domain" Switcher.spaceScope -string "allSpaces"

# Timing
defaults write "$domain" Switcher.revealDelayMs -int 100
defaults write "$domain" Switcher.letterChainTimeoutMs -int 1000
defaults write "$domain" Switcher.titleRefreshIntervalMs -int 200

# Contents
defaults write "$domain" Switcher.showMinimizedWindows -bool true
defaults write "$domain" Switcher.showHiddenApps -bool true
defaults write "$domain" Switcher.showWindowlessApps -bool true
defaults write "$domain" Switcher.applicationsOnly -bool false
defaults write "$domain" Switcher.showUnreadBadges -bool true
defaults write "$domain" Switcher.showRecentlyClosed -bool false
defaults write "$domain" Switcher.recentlyClosedLimit -int 5

# Tabs
defaults write "$domain" Switcher.tabDrillEnabled -bool true
defaults write "$domain" Switcher.windowDrillEnabled -bool true
defaults write "$domain" Switcher.expandTabsAsWindows -bool false
defaults write "$domain" Switcher.expandBrowserTabsAsWindows -bool false
defaults write "$domain" Switcher.browserTabRowLimit -int 0
defaults write "$domain" Switcher.showBrowserIconOnTabs -bool false

# Search
defaults write "$domain" Switcher.fuzzySearchEnabled -bool true
defaults write "$domain" Switcher.letterHintsEnabled -bool false
defaults write "$domain" Switcher.searchDismissMode -string "stayOpen"
defaults write "$domain" Switcher.searchIncludesLaunchableApps -bool true
defaults write "$domain" Switcher.fuzzySearchRankBestMatchFirst -bool false
defaults write "$domain" Switcher.searchExpandsBrowserTabs -bool false

# Keyboard
defaults write "$domain" Switcher.stayOpenOnRelease -bool false
defaults write "$domain" Switcher.stayOpenOnQuickTap -bool false
defaults write "$domain" Switcher.shiftTapStepsBackward -bool true
defaults write "$domain" Switcher.backtickReversesAppSwitching -bool false
defaults write "$domain" Switcher.vimNavigationEnabled -bool true

# Mouse
defaults write "$domain" Switcher.scrollToSwitch -bool false
defaults write "$domain" Switcher.scrollReverseDirection -bool false
defaults write "$domain" Switcher.clickOutsideToDismiss -bool true
defaults write "$domain" Switcher.mouseHoverSelectionEnabled -bool false
defaults write "$domain" Switcher.mouseClickSelectionEnabled -bool true
defaults write "$domain" Switcher.hoverActionsEnabled -bool true
defaults write "$domain" Switcher.hoverShowClose -bool true
defaults write "$domain" Switcher.hoverShowMinimize -bool true
defaults write "$domain" Switcher.hoverShowMaximize -bool true
defaults write "$domain" Switcher.hoverShowHide -bool true
defaults write "$domain" Switcher.hoverShowQuit -bool true
defaults write "$domain" Switcher.hoverShowForceQuit -bool false

# Appearance
defaults write "$domain" Switcher.panelScalePercent -int 120
defaults write "$domain" Switcher.panelAppearance -string "system"
defaults write "$domain" Switcher.fontScale -string "standard"
defaults write "$domain" Switcher.fontFace -string "monospaced"
defaults write "$domain" Switcher.gridMaxColumns -int 0
defaults write "$domain" Switcher.listWidthPercent -int 100
defaults write "$domain" Switcher.panelOpacity -int 100
defaults write "$domain" Switcher.panelCornerRadius -int 0
defaults write "$domain" Switcher.backdropMaterial -string "hud"
defaults write "$domain" Switcher.showWindowTitleLabel -bool true
defaults write "$domain" Switcher.showApplicationNames -bool true
defaults write "$domain" Switcher.previewTitleAlignment -string "center"
defaults write "$domain" Switcher.titleTruncationMode -string "tail"
defaults write "$domain" Switcher.boldSelectedLabel -bool true

# Feedback
defaults write "$domain" Switcher.hapticOnCommit -bool false
defaults write "$domain" Switcher.soundOnCommit -bool false
defaults write "$domain" Switcher.commitSoundName -string "Tink"

# Privacy
defaults write "$domain" Switcher.hideMenuBarIcon -bool false
defaults write "$domain" Switcher.hideFromScreenSharing -bool true

# Experimental
defaults write "$domain" Switcher.cycleTileWidths -bool true
defaults write "$domain" Switcher.experimentalSwipeTrigger -bool false
defaults write "$domain" Switcher.swipeMode -string "openSwitcher"
defaults write "$domain" Switcher.swipeReverseDirection -bool false
defaults write "$domain" Switcher.swipeCommitOnRelease -bool false
defaults write "$domain" Switcher.swipeSensitivity -int 5
defaults write "$domain" Switcher.experimentalInstantSpaceSwitch -bool true
defaults write "$domain" Switcher.experimentalBrowserTabMRU -bool true
defaults write "$domain" Switcher.experimentalBrowserTabPreviews -bool true
defaults write "$domain" Switcher.experimentalLivePreviews -bool false

# Hotkeys (⌥Tab / ⌥`)
defaults write "$domain" BetterShortcuts_switchApps \
    -string '{"carbonKeyCode":48,"carbonModifiers":2048}'
defaults write "$domain" BetterShortcuts_switchWindows \
    -string '{"carbonKeyCode":50,"carbonModifiers":2048}'

# Restart the app to apply settings
if pgrep -x BetterCmdTab &>/dev/null; then
    killall BetterCmdTab 2>/dev/null
    sleep 1
    open -a BetterCmdTab
fi
