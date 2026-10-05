#!/bin/bash
# Shared helpers for install.sh at the repo root and every package's install.sh.
#
# Sourced, never executed. Package scripts reach it via:
#   . "$(dirname "$0")/../lib/common.sh"
# and the root script via:
#   . "$(dirname "$0")/lib/common.sh"
#
# Homebrew is the primary package manager on both macOS and Linux, but only
# where it can pour a bottle: Homebrew stopped building bottles for Intel
# macOS in September 2026, and a source build there drags in rust, llvm or go
# and runs for hours. ensure_cmd therefore pours a bottle when one exists for
# this machine, otherwise installs the tool's own release build for this
# OS/CPU into ~/.local/bin, and compiles with Homebrew only for tools that have
# no release build. The distro package manager is used only for the things
# that are inherently system integration and that brew either can't provide or
# shouldn't own: Homebrew's own build prerequisites, the display-server
# clipboard bridges, fontconfig, and the login shell.

# Guard against double-sourcing — nvim/install.sh sources clangd/install.sh,
# which sources this file too.
[ -n "${DOTFILES_COMMON_SH:-}" ] && return 0
DOTFILES_COMMON_SH=1

# ---------- platform ----------

case "$(uname -s)" in
	Darwin) DOTFILES_OS=macos ;;
	Linux) DOTFILES_OS=linux ;;
	*) DOTFILES_OS=unknown ;;
esac
export DOTFILES_OS

is_macos() { [ "$DOTFILES_OS" = macos ]; }
is_linux() { [ "$DOTFILES_OS" = linux ]; }

# Native CPU as x86_64 or arm64. A shell running under Rosetta reports x86_64
# from uname, so ask the kernel whether the process is translated.
machine_arch() {
	case "$(uname -m)" in
	arm64 | aarch64) echo arm64 ;;
	x86_64 | amd64)
		if is_macos && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = 1 ]; then
			echo arm64
		else
			echo x86_64
		fi
		;;
	*) uname -m ;;
	esac
}

have() { command -v "$1" >/dev/null 2>&1; }

# Release builds and uv tools land here; keep it ahead of the brew prefix so a
# fallback install (say, a current nvim beside an old unbottled brew one) wins.
LOCAL_BIN="$HOME/.local/bin"
case ":$PATH:" in *":$LOCAL_BIN:"*) ;; *) PATH="$LOCAL_BIN:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.opencode/bin:"*) ;; *) PATH="$PATH:$HOME/.opencode/bin" ;; esac
export PATH

info() { echo "$*"; }
warn() { echo "⚠️  $*" >&2; }

# True when there is a human available to answer a prompt.
interactive() { [ -t 0 ] && [ -t 1 ]; }

# Ask a yes/no question. Non-interactive runs answer "no", so an unattended
# install never blocks on an unanswerable prompt. Root install.sh exports
# DOTFILES_ASSUME_YES=1 once the user has agreed to stow everything (via -y or
# the "stow all" prompt), so every confirm() downstream — including inside a
# package's own install.sh — answers yes without asking again.
confirm() {
	local ans
	[ "${DOTFILES_ASSUME_YES:-}" = "1" ] && return 0
	interactive || return 1
	printf '%s [y/N] ' "$1"
	read -r ans || return 1
	case "$ans" in y | Y | yes | YES) return 0 ;; *) return 1 ;; esac
}

# ---------- distro package managers (Linux only) ----------

# The system package manager, or non-zero if none is recognised.
#
# Detected by which binary exists, not by /etc/os-release ID: derivatives are
# the common case (Kubuntu, Mint, Pop!_OS, CachyOS, EndeavourOS, Nobara), they
# all report their own ID, and what actually matters here is which tool is
# present. Order matters only for the rare box carrying two.
pkg_mgr() {
	is_linux || return 1
	if [ -n "${_PKG_MGR:-}" ]; then
		echo "$_PKG_MGR"
		return 0
	fi
	local m
	for m in apt-get dnf yum zypper pacman apk; do
		if have "$m"; then
			_PKG_MGR=$m
			echo "$m"
			return 0
		fi
	done
	return 1
}

# _pkg_name GENERIC MGR — most packages carry the same name everywhere; this
# translates only the ones that do not. Empty output means "not applicable
# here", so a caller can list a package that only some distros split out.
_pkg_name() {
	case "$1" in
	procps) case "$2" in dnf | yum | pacman) echo procps-ng ;; *) echo procps ;; esac ;;
	*) echo "$1" ;;
	esac
}

_pkg_index_refreshed=0

# pkg_install PKG... — install distro packages by their common name.
#
# Returns non-zero (without failing the caller's script) when no supported
# package manager exists, so every caller can degrade to a warning instead of
# assuming one distro family. Only apt needs an explicit index refresh; it is
# done once per *process*, and since root install.sh runs each package's
# installer as its own `bash`, that is per-script rather than per-run.
pkg_install() {
	is_linux || return 1
	local mgr
	mgr=$(pkg_mgr) || {
		warn "no supported package manager found — install manually: $*"
		return 1
	}
	local pkgs=() p name
	for p in "$@"; do
		name=$(_pkg_name "$p" "$mgr")
		# Deliberately unquoted: a translation may expand to several packages.
		# shellcheck disable=SC2206
		[ -n "$name" ] && pkgs+=($name)
	done
	[ "${#pkgs[@]}" -gt 0 ] || return 0

	case "$mgr" in
	apt-get)
		if [ "$_pkg_index_refreshed" -eq 0 ]; then
			sudo apt-get update -qq || warn "apt-get update failed — continuing with a stale index"
			_pkg_index_refreshed=1
		fi
		sudo apt-get install -y "${pkgs[@]}"
		;;
	dnf | yum) sudo "$mgr" install -y "${pkgs[@]}" ;;
	zypper) sudo zypper --non-interactive install "${pkgs[@]}" ;;
	pacman) sudo pacman -S --needed --noconfirm "${pkgs[@]}" ;;
	apk) sudo apk add "${pkgs[@]}" ;;
	esac
}

# True when the distro's own repositories offer PKG. Asking first keeps a
# missing package from surfacing as an install error when a fallback exists.
pkg_available() {
	local mgr
	mgr=$(pkg_mgr) || return 1
	case "$mgr" in
	apt-get) apt-cache show "$1" >/dev/null 2>&1 ;;
	dnf | yum) "$mgr" list --available "$1" >/dev/null 2>&1 ;;
	zypper) zypper --non-interactive info "$1" 2>/dev/null | grep -q '^Version' ;;
	pacman) pacman -Si "$1" >/dev/null 2>&1 ;;
	apk) apk search -e "$1" 2>/dev/null | grep -q . ;;
	*) return 1 ;;
	esac
}

# ---------- remote installers ----------

# run_remote_installer URL [ARG...] — download a remote install script, run it,
# and return its real exit status.
#
# The two obvious spellings both report success when the download fails, so a
# 404 or an offline machine reads as a completed install:
#   curl -fsSL URL | sh          → pipeline status is sh's, and sh with empty
#                                  input exits 0.
#   bash -c "$(curl -fsSL URL)"  → command substitution discards curl's status,
#                                  and `bash -c ""` exits 0.
# Downloading first is what makes `|| warn` mean anything.
run_remote_installer() {
	local url=$1 tmp rc
	shift
	tmp=$(mktemp "${TMPDIR:-/tmp}/remote-install.XXXXXX") || return 1
	if ! curl -fsSL "$url" -o "$tmp"; then
		rm -f "$tmp"
		warn "could not download $url"
		return 1
	fi
	# An error page or a truncated transfer is worse than no script at all.
	if [ ! -s "$tmp" ]; then
		rm -f "$tmp"
		warn "downloaded an empty script from $url"
		return 1
	fi
	bash "$tmp" "$@"
	rc=$?
	rm -f "$tmp"
	return "$rc"
}

# ---------- Homebrew ----------

# Absolute brew path for this machine, or empty. Homebrew is not on PATH during
# the run that installs it, so every caller resolves it through here rather than
# assuming `brew` is already callable.
brew_bin() {
	if have brew; then
		command -v brew
		return 0
	fi
	local p
	for p in /opt/homebrew/bin/brew /usr/local/bin/brew \
		/home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
		[ -x "$p" ] && {
			echo "$p"
			return 0
		}
	done
	return 1
}

# Put brew on PATH for the rest of this process, behind ~/.local/bin.
brew_shellenv() {
	local b
	b=$(brew_bin) || return 1
	eval "$("$b" shellenv)"
	PATH="$LOCAL_BIN:${PATH//":$LOCAL_BIN:"/:}"
	export PATH
}

# Homebrew's documented build prerequisites, per distro family. Homebrew checks
# for these but does not install them, and on a fresh machine curl is often
# among the missing — which would otherwise kill the installer on its own first
# line, before anything else in this repo gets a chance to run.
brew_prereqs() {
	local mgr
	mgr=$(pkg_mgr) || {
		warn "unknown package manager — install Homebrew's prerequisites manually:"
		warn "  a C compiler, make, procps, curl, file and git"
		return 1
	}
	case "$mgr" in
	apt-get) pkg_install build-essential procps curl file git ;;
	pacman) pkg_install base-devel procps curl file git ;;
	apk) pkg_install build-base procps curl file git ;;
	# Fedora/RHEL and openSUSE ship their toolchain as a group/pattern rather
	# than a single package, which ensure_build_tools already knows how to ask
	# for; the rest are ordinary packages.
	dnf | yum | zypper)
		ensure_build_tools
		pkg_install procps curl file git
		;;
	esac
}

# Install Homebrew if absent and leave it on PATH. Homebrew's own installer
# handles interactivity (it sets NONINTERACTIVE itself when stdin is not a TTY).
brew_bootstrap() {
	if brew_shellenv 2>/dev/null && have brew; then
		return 0
	fi

	if is_linux; then
		info "Installing Homebrew prerequisites..."
		brew_prereqs ||
			warn "could not install Homebrew prerequisites — the installer below may fail"
	fi

	info "Installing Homebrew..."
	# Homebrew's installer already sets NONINTERACTIVE itself when stdin is not a
	# TTY; an attended run that has already agreed to DOTFILES_ASSUME_YES gets the
	# same treatment so it skips Homebrew's own "Press RETURN to continue" prompt.
	(
		[ "${DOTFILES_ASSUME_YES:-}" = "1" ] && export NONINTERACTIVE=1
		run_remote_installer https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
	) || warn "the Homebrew installer did not complete"

	brew_shellenv 2>/dev/null
	have brew || {
		warn "Homebrew install failed"
		return 1
	}
}

# ---------- Homebrew bottles ----------

# Bottle tags this Homebrew can pour, as one JSON array. Homebrew pours a
# bottle built for an older macOS on a newer one, never the reverse. The
# architecture is Homebrew's own: an Intel Homebrew in /usr/local on an Apple
# Silicon Mac runs under Rosetta and pours Intel bottles.
brew_bottle_tags() {
	local prefix="" major entry tags=""
	if is_linux; then
		case "$(machine_arch)" in
		x86_64) tags='"x86_64_linux"' ;;
		arm64) tags='"arm64_linux"' ;;
		esac
	elif is_macos; then
		case "$(brew --prefix 2>/dev/null)" in /opt/homebrew) prefix=arm64_ ;; esac
		major=$(sw_vers -productVersion 2>/dev/null)
		major=${major%%.*}
		for entry in golden_gate:27 tahoe:26 sequoia:15 sonoma:14 ventura:13 monterey:12 big_sur:11; do
			[ "${entry##*:}" -le "${major:-0}" ] && tags="$tags\"$prefix${entry%%:*}\","
		done
		tags=${tags%,}
	fi
	echo "[${tags:+$tags,}\"all\"]"
}

# True on the platforms Homebrew still builds bottles for (everything except
# Intel macOS). Only used when jq is not available to ask about a formula.
brew_platform_bottled() {
	! { is_macos && [ "$(brew --prefix 2>/dev/null)" = /usr/local ]; }
}

# brew_can_pour FORMULA... — true when `brew install FORMULA...` would pour
# every formula, and every dependency it adds or upgrades, from a bottle.
#
# Upgrading an installed dependency counts too: on Intel macOS that upgrade can
# itself be a source build, and a bottle upgrade there has no bottled
# dependents to repair linkage with — a z3 upgrade left an installed llvm
# unable to load libz3. So where bottles are not built, any upgrade of an
# installed dependency blocks the pour.
brew_can_pour() {
	have brew || return 1
	have jq || {
		brew_platform_bottled
		return
	}
	local deps json upgrades=true
	brew_platform_bottled || upgrades=false
	# --formula: a name that exists only as a cask (codex) would otherwise
	# yield no formulae at all, and `all` of an empty list is true.
	deps=$(brew deps --formula --union "$@" 2>/dev/null) || return 1
	# shellcheck disable=SC2086 # one formula name per word
	json=$(brew info --json=v2 --formula "$@" $deps 2>/dev/null) || return 1
	jq -e --argjson tags "$(brew_bottle_tags)" --argjson upgrades "$upgrades" '
		(.formulae | length) > 0 and
		([.formulae[]
		  | select((.installed | length) == 0 or .outdated)
		  | if (.installed | length) > 0 and ($upgrades | not) then false
		    else (.bottle.stable.files // {} | keys) as $have | any($have[]; IN($tags[])) end]
		 | all)' <<<"$json" >/dev/null
}

# ---------- upstream release builds ----------

LOCAL_OPT="$HOME/.local/opt"

# _arch_pick MACOS_X86_64 MACOS_ARM64 LINUX_X86_64 LINUX_ARM64 — the argument
# naming this machine in a project's own asset-naming scheme.
_arch_pick() {
	case "$DOTFILES_OS-$(machine_arch)" in
	macos-x86_64) echo "$1" ;;
	macos-arm64) echo "$2" ;;
	linux-x86_64) echo "$3" ;;
	linux-arm64) echo "$4" ;;
	*) return 1 ;;
	esac
}

# Rust-style target triple; musl on Linux so the binary runs on any glibc.
_rust_target() {
	_arch_pick x86_64-apple-darwin aarch64-apple-darwin \
		x86_64-unknown-linux-musl aarch64-unknown-linux-musl
}

# gh_latest_tag OWNER/REPO — tag of the latest release, read from where the
# releases/latest page redirects rather than from the REST API, which allows
# only 60 unauthenticated requests an hour.
gh_latest_tag() {
	local url
	url=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest") || return 1
	case "$url" in
	*/releases/tag/*) echo "${url##*/releases/tag/}" ;;
	*) return 1 ;;
	esac
}

# gh_asset_url OWNER/REPO ASSET — download URL of ASSET in the latest release.
# ASSET may contain {tag}, or {version} for the tag without a leading "v";
# assets without either go through the stable releases/latest/download path.
gh_asset_url() {
	local repo=$1 asset=$2 tag
	case "$asset" in
	*"{tag}"* | *"{version}"*)
		tag=$(gh_latest_tag "$repo") || {
			warn "could not resolve the latest $repo release"
			return 1
		}
		asset=${asset//\{tag\}/$tag}
		asset=${asset//\{version\}/${tag#v}}
		echo "https://github.com/$repo/releases/download/$tag/$asset"
		;;
	*) echo "https://github.com/$repo/releases/latest/download/$asset" ;;
	esac
}

# _fetch_unpack URL DIR — download URL and unpack it into DIR by its extension;
# anything that is not an archive is taken to be the executable itself.
_fetch_unpack() {
	local url=$1 dir=$2 file
	file="$dir/.download/${url##*/}"
	mkdir -p "$dir/.download" || return 1
	curl -fsSL --retry 2 -o "$file" "$url" || return 1
	case "$file" in
	*.tar.gz | *.tgz) tar -xzf "$file" -C "$dir" ;;
	*.tar.xz) tar -xJf "$file" -C "$dir" ;;
	*.zip)
		have unzip || pkg_install unzip || return 1
		unzip -qo "$file" -d "$dir"
		;;
	*.gz) gzip -dc "$file" >"$dir/$(basename "${file%.gz}")" ;;
	*) cp "$file" "$dir/" ;;
	esac || return 1
	rm -rf "$dir/.download"
}

# prebuilt_bin URL NAME[:GLOB]... — install the executable matching GLOB
# (default NAME) inside the release asset at URL as ~/.local/bin/NAME.
prebuilt_bin() {
	local url=$1 tmp spec name glob found rc=0
	shift
	tmp=$(mktemp -d "${TMPDIR:-/tmp}/prebuilt.XXXXXX") || return 1
	if _fetch_unpack "$url" "$tmp"; then
		mkdir -p "$LOCAL_BIN" || rc=1
		for spec in "$@"; do
			name=${spec%%:*}
			glob=${spec#*:}
			found=$(find "$tmp" -type f -name "$glob" | head -n 1)
			if [ -n "$found" ] && chmod 755 "$found" && mv -f "$found" "$LOCAL_BIN/$name"; then
				info "Installed $name to $LOCAL_BIN"
			else
				warn "$url has no $glob"
				rc=1
			fi
		done
	else
		warn "could not download $url"
		rc=1
	fi
	rm -rf "$tmp"
	return "$rc"
}

# prebuilt_tree URL NAME — unpack the release asset at URL as ~/.local/opt/NAME,
# replacing an earlier copy only once the new one is complete. For tools that
# find their runtime files relative to the binary (nvim, lua-language-server).
prebuilt_tree() {
	local url=$1 name=$2 tmp root dest="$LOCAL_OPT/$2" rc=1
	# Staged inside $LOCAL_OPT so the final mv is a rename, not a copy from
	# another filesystem (/tmp is often tmpfs) that can fail halfway.
	mkdir -p "$LOCAL_OPT" || return 1
	tmp=$(mktemp -d "$LOCAL_OPT/.$name.XXXXXX") || return 1
	if _fetch_unpack "$url" "$tmp/x"; then
		# Most archives wrap everything in one directory (nvim-macos-x86_64/);
		# some (lua-language-server) unpack straight into the current one.
		root="$tmp/x"
		if [ "$(find "$tmp/x" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ]; then
			root=$(find "$tmp/x" -mindepth 1 -maxdepth 1 -type d)
			[ -n "$root" ] || root="$tmp/x"
		fi
		if rm -rf "$dest.old" && { [ ! -e "$dest" ] || mv "$dest" "$dest.old"; }; then
			if mv "$root" "$dest"; then
				rm -rf "$dest.old"
				rc=0
			elif [ -e "$dest.old" ]; then
				mv "$dest.old" "$dest"
			fi
		fi
	else
		warn "could not download $url"
	fi
	rm -rf "$tmp"
	return "$rc"
}

# _bin_wrapper NAME COMMAND — ~/.local/bin/NAME as a script that execs
# COMMAND (already shell-quoted where needed) with the caller's arguments.
_bin_wrapper() {
	mkdir -p "$LOCAL_BIN" &&
		printf '#!/bin/sh\n%s "$@"\n' "$2" >"$LOCAL_BIN/$1" &&
		chmod 755 "$LOCAL_BIN/$1"
}

# The official installers for uv/ruff/ty edit shell startup files, which here
# are stowed into the repo, so uv comes from its release archive instead.
ensure_uv() {
	have uv && return 0
	if brew_can_pour uv; then
		brew install uv && return 0
	fi
	prebuilt_bin "$(gh_asset_url astral-sh/uv "uv-$(_rust_target).tar.gz")" uv uvx
}

# uv_tool NAME — install a PyPI-packaged binary (ruff, ty, clangd,
# clang-format all publish wheels for every OS/CPU here) into ~/.local/bin.
uv_tool() {
	ensure_uv || return 1
	# --force: without it uv skips an installed tool even when its link in
	# ~/.local/bin is gone, which is exactly when this gets called.
	UV_TOOL_BIN_DIR="$LOCAL_BIN" uv tool install --quiet --force "$1"
}

# prebuilt_install COMMAND — install COMMAND from its project's own release
# build for this OS/CPU. Returns 2 when there is none to fall back on, and 1
# for any failure: the `|| return 1` after esac keeps a tool's own exit 2 (uv
# when PyPI is unreachable) from reading as "no release build" and starting a
# source build. An arm that runs `return` leaves before that applies.
prebuilt_install() {
	local cmd=$1 asset
	case "$cmd" in
	bat | fd)
		prebuilt_bin "$(gh_asset_url "sharkdp/$cmd" "$cmd-{tag}-$(_rust_target).tar.gz")" "$cmd"
		;;
	eza)
		# eza publishes Linux builds only; on macOS build it with an existing
		# Rust toolchain rather than through Homebrew's rust → llvm chain.
		if is_linux; then
			asset=$(_arch_pick "" "" x86_64-unknown-linux-musl aarch64-unknown-linux-gnu)
			prebuilt_bin "$(gh_asset_url eza-community/eza "eza_$asset.tar.gz")" eza
		elif have cargo; then
			info "Building eza with cargo (no bottle or release build for this Mac)..."
			cargo install --locked --root "$HOME/.local" eza
		else
			# Homebrew's own source build would compile rust and llvm first.
			warn "eza has no bottle or release build for this Mac — install Rust (https://rustup.rs) and re-run"
			return 1
		fi
		;;
	starship)
		prebuilt_bin "$(gh_asset_url starship/starship "starship-$(_rust_target).tar.gz")" starship
		;;
	zoxide)
		prebuilt_bin "$(gh_asset_url ajeetdsouza/zoxide "zoxide-{version}-$(_rust_target).tar.gz")" zoxide
		;;
	rg)
		asset=$(_arch_pick x86_64-apple-darwin aarch64-apple-darwin \
			x86_64-unknown-linux-musl aarch64-unknown-linux-musl)
		prebuilt_bin "$(gh_asset_url BurntSushi/ripgrep "ripgrep-{tag}-$asset.tar.gz")" rg
		;;
	fzf)
		asset=$(_arch_pick darwin_amd64 darwin_arm64 linux_amd64 linux_arm64)
		prebuilt_bin "$(gh_asset_url junegunn/fzf "fzf-{version}-$asset.tar.gz")" fzf
		;;
	jq)
		asset=$(_arch_pick macos-amd64 macos-arm64 linux-amd64 linux-arm64)
		prebuilt_bin "$(gh_asset_url jqlang/jq "jq-$asset")" "jq:jq-$asset"
		;;
	lf)
		asset=$(_arch_pick darwin-amd64 darwin-arm64 linux-amd64 linux-arm64)
		prebuilt_bin "$(gh_asset_url gokcehan/lf "lf-$asset.tar.gz")" lf
		;;
	shellcheck)
		asset=$(_arch_pick darwin.x86_64 darwin.aarch64 linux.x86_64 linux.aarch64)
		prebuilt_bin "$(gh_asset_url koalaman/shellcheck "shellcheck-{tag}.$asset.tar.gz")" shellcheck
		;;
	stylua)
		asset=$(_arch_pick macos-x86_64 macos-aarch64 linux-x86_64 linux-aarch64)
		prebuilt_bin "$(gh_asset_url JohnnyMorganz/StyLua "stylua-$asset.zip")" stylua
		;;
	marksman)
		asset=$(_arch_pick macos macos linux-x64 linux-arm64)
		if is_macos; then
			prebuilt_bin "$(gh_asset_url artempyanykh/marksman "marksman-$asset")" "marksman:marksman-$asset"
		else
			# A .NET build: it aborts at startup without libicu, which minimal
			# distros lack, and a Markdown server needs no culture data.
			LOCAL_BIN="$LOCAL_OPT/marksman" prebuilt_bin \
				"$(gh_asset_url artempyanykh/marksman "marksman-$asset")" "marksman:marksman-$asset" &&
				_bin_wrapper marksman "DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 exec \"$LOCAL_OPT/marksman/marksman\""
		fi
		;;
	rust-analyzer)
		asset=$(_arch_pick x86_64-apple-darwin aarch64-apple-darwin \
			x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu)
		prebuilt_bin "$(gh_asset_url rust-lang/rust-analyzer "rust-analyzer-$asset.gz")" \
			"rust-analyzer:rust-analyzer-$asset"
		;;
	tree-sitter)
		asset=$(_arch_pick macos-x64 macos-arm64 linux-x64 linux-arm64)
		prebuilt_bin "$(gh_asset_url tree-sitter/tree-sitter "tree-sitter-$asset.gz")" \
			"tree-sitter:tree-sitter-$asset"
		;;
	lua-language-server)
		asset=$(_arch_pick darwin-x64 darwin-arm64 linux-x64 linux-arm64)
		prebuilt_tree "$(gh_asset_url LuaLS/lua-language-server \
			"lua-language-server-{version}-$asset.tar.gz")" lua-language-server || return 1
		# A wrapper, not a symlink: the server locates main.lua from the path
		# it was started by.
		_bin_wrapper lua-language-server "exec \"$LOCAL_OPT/lua-language-server/bin/lua-language-server\""
		;;
	nvim)
		asset=$(_arch_pick macos-x86_64 macos-arm64 linux-x86_64 linux-arm64)
		prebuilt_tree "$(gh_asset_url neovim/neovim "nvim-$asset.tar.gz")" nvim &&
			mkdir -p "$LOCAL_BIN" && ln -sfn "$LOCAL_OPT/nvim/bin/nvim" "$LOCAL_BIN/nvim"
		;;
	ruff | ty | clangd | clang-format) uv_tool "$cmd" ;;
	uv) ensure_uv ;;
	codex)
		prebuilt_bin "$(gh_asset_url openai/codex "codex-$(_rust_target).tar.gz")" \
			"codex:codex-$(_rust_target)"
		;;
	opencode)
		# Its installer would append to $ZDOTDIR/.zshrc — a file stowed from
		# this repo; ~/.opencode/bin is on the dotfiles PATH already.
		run_remote_installer https://opencode.ai/install --no-modify-path
		;;
	*) return 2 ;;
	esac || return 1
}

# ensure_cmd COMMAND [FORMULA] — make COMMAND available unless it already
# resolves: pour FORMULA (default: COMMAND) when Homebrew has a bottle for this
# machine, else install the project's own release build, else — only for tools
# that publish none, such as tmux — let Homebrew build FORMULA from source.
# The command/formula split matters because several formulae are named
# differently from the binary they ship (rg/ripgrep).
ensure_cmd() {
	local cmd=$1 formula=${2:-$1} rc
	have "$cmd" && return 0
	if brew_can_pour "$formula"; then
		brew install --formula "$formula" && have "$cmd" && return 0
		warn "brew install $formula failed — trying the upstream release build"
	fi
	prebuilt_install "$cmd"
	rc=$?
	if [ "$rc" -eq 0 ]; then
		have "$cmd" && return 0
		warn "$cmd still not on PATH after installing it"
		return 1
	fi
	# A release build that exists but failed to download is not a reason to
	# start an hours-long compile; report it and let the caller carry on.
	[ "$rc" -eq 2 ] || return 1
	if ! have brew; then
		# The tools without a release build (tmux, bc, curl) carry the same
		# name in every distro's repositories.
		is_linux && pkg_install "$formula" && have "$cmd" && return 0
		warn "$cmd missing and brew unavailable — install $formula manually"
		return 1
	fi
	info "No Homebrew bottle for $formula on this machine — building it from source..."
	brew install --formula "$formula"
}

# ensure_cask CASK APP — install CASK unless APP (Name.app) is already in
# /Applications or ~/Applications. A copy installed outside Homebrew makes the
# cask fail with "It seems there is already an App at ...".
ensure_cask() {
	local cask=$1 app=$2
	if [ -d "/Applications/$app" ] || [ -d "$HOME/Applications/$app" ]; then
		return 0
	fi
	have brew || {
		warn "brew unavailable — install $cask manually"
		return 1
	}
	[ -d "$(brew --prefix)/Caskroom/$cask" ] && return 0
	brew install --cask "$cask"
}

# ---------- shared dependencies ----------

# A C toolchain + make, needed by nvim-treesitter's parser compilation and
# telescope-fzf-native's `make` build step.
ensure_build_tools() {
	if is_macos; then
		xcode-select -p >/dev/null 2>&1 && return 0
		warn "Xcode Command Line Tools missing — treesitter parsers and telescope-fzf-native will not build."
		warn "  Install them with: xcode-select --install"
		return 1
	fi
	have cc && have make && return 0
	local mgr
	mgr=$(pkg_mgr) || {
		warn "unknown package manager — install a C compiler and make manually,"
		warn "  or treesitter parsers and telescope-fzf-native will not build"
		return 1
	}
	info "Installing build toolchain..."
	case "$mgr" in
	apt-get) pkg_install build-essential ;;
	pacman) pkg_install base-devel ;;
	apk) pkg_install build-base ;;
	# Groups and patterns are not ordinary packages, so these bypass
	# pkg_install; the plain-package fallback covers a stripped-down image
	# where the group metadata is unavailable.
	dnf | yum) sudo "$mgr" group install -y development-tools ||
		sudo "$mgr" install -y gcc gcc-c++ make ;;
	zypper) sudo zypper --non-interactive install -t pattern devel_basis ||
		sudo zypper --non-interactive install gcc gcc-c++ make ;;
	esac || warn "no C toolchain — treesitter parsers will fail to compile"
}

# Clipboard bridges for tmux and Neovim; macOS has pbcopy built in.
# Both Wayland and X11 helpers are installed because the session type at
# install time need not match the session the user ends up running.
ensure_clipboard() {
	is_macos && return 0
	local missing=()
	have wl-copy || missing+=(wl-clipboard)
	have xclip || have xsel || missing+=(xclip)
	[ "${#missing[@]}" -gt 0 ] || return 0
	info "Installing clipboard bridges (${missing[*]})..."
	pkg_install "${missing[@]}" || {
		warn "clipboard bridge installation failed: ${missing[*]}"
		return 1
	}
}

# starship.toml, `eza --icons`, lf's icons file and the tmux status bar all
# render Nerd Font glyphs. Without a patched font every one of them shows tofu.
# The Nerd Font build of Fira Code also covers kitty.conf's plain "Fira Code"
# family via the terminals' own per-glyph font fallback.
ensure_nerd_font() {
	local zip dir tmpdir rc

	# fc-list is the reliable check where it exists; macOS usually has no
	# fontconfig, so fall back to looking in the font directories themselves.
	if have fc-list && fc-list 2>/dev/null | grep -qi "FiraCode Nerd Font"; then
		return 0
	fi
	# Both layouts have to be checked: the cask drops the .ttf files straight
	# into fontdir, while the zip fallback below nests them in a subdirectory.
	if ls "$HOME/Library/Fonts"/FiraCodeNerdFont* >/dev/null 2>&1 ||
		ls /Library/Fonts/FiraCodeNerdFont* >/dev/null 2>&1 ||
		ls "$HOME/.local/share/fonts"/FiraCodeNerdFont* >/dev/null 2>&1 ||
		ls "$HOME/.local/share/fonts"/*/FiraCodeNerdFont* >/dev/null 2>&1; then
		return 0
	fi

	# One path for both platforms: the font-fira-code-nerd-font cask declares no
	# macOS dependency, and Homebrew's Linux cask config sets fontdir to
	# ~/.local/share/fonts, so the cask installs correctly on Linux too.
	if have brew; then
		info "Installing FiraCode Nerd Font..."
		if brew install --cask font-fira-code-nerd-font; then
			have fc-cache && fc-cache -f >/dev/null 2>&1
			return 0
		fi
		warn "cask install failed — falling back to the nerd-fonts release"
	fi

	# Fallback for a machine where the Homebrew bootstrap did not succeed.
	is_linux || {
		warn "install FiraCode Nerd Font manually — icons will render as tofu"
		return 1
	}
	have unzip || pkg_install unzip || {
		warn "unzip missing — cannot install FiraCode Nerd Font"
		return 1
	}
	have fc-cache || pkg_install fontconfig || warn "fontconfig missing — font cache will not refresh"

	dir="$HOME/.local/share/fonts/FiraCodeNerdFont"
	# A temp *directory*, not `mktemp <tmpl>.zip`: both BSD and GNU mktemp only
	# substitute Xs that end the template, so a ".zip" suffix would yield the
	# literal, guessable path /tmp/FiraCode.XXXXXX.zip.
	tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/firacode.XXXXXX") || return 1
	zip="$tmpdir/FiraCode.zip"
	rc=0
	if curl -fsSL -o "$zip" \
		https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip; then
		mkdir -p "$dir"
		unzip -oq "$zip" -x 'README*' 'LICENSE*' -d "$dir" || rc=1
		[ "$rc" -eq 0 ] && have fc-cache && fc-cache -f "$dir" >/dev/null 2>&1
	else
		warn "could not download FiraCode Nerd Font — icons will render as tofu"
		rc=1
	fi
	# Report the real outcome: `rm -rf` as the last statement would otherwise
	# make a failed download return 0, contradicting the branches above.
	rm -rf "$tmpdir"
	return "$rc"
}

# True when node and npm are on PATH and node's major version is at least $1.
_node_ok() {
	have node && have npm &&
		[ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -ge "${1:-0}" ]
}

# ensure_node [MIN_MAJOR] — node and npm for the globally-installed CLIs
# (claude-agent-acp needs node 22+, @playwright/cli 18+). nvm owns node on both
# platforms, so global installs land in the node the shell puts on PATH (see
# the nvm section of .zshrc) rather than in a distro node that needs sudo.
# This runs in non-interactive bash, where .zshrc's lazy nvm shims never load.
ensure_node() {
	local min=${1:-0} default
	export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

	if [ ! -s "$NVM_DIR/nvm.sh" ]; then
		info "Installing nvm..."
		PROFILE=/dev/null run_remote_installer https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh ||
			warn "nvm install failed"
	fi
	if [ ! -s "$NVM_DIR/nvm.sh" ]; then
		_node_ok "$min"
		return
	fi

	# shellcheck disable=SC1091
	. "$NVM_DIR/nvm.sh" >/dev/null 2>&1
	_node_ok "$min" && return 0

	info "Installing the latest LTS node (nvm)..."
	nvm install --lts >/dev/null 2>&1 || {
		warn "node install failed"
		return 1
	}
	_node_ok "$min" || return 1
	# nvm install switched only this process. Global CLIs installed now live
	# under this node, which the shell puts on PATH only if it is the default.
	default=$(nvm version default 2>/dev/null)
	case "$default" in
	"$(node --version)") ;;
	*) warn "nvm's default node is ${default:-unset}; run 'nvm alias default lts/*' to use the CLIs installed for $(node --version)" ;;
	esac
}
