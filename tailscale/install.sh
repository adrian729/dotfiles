#!/bin/bash
# Install missing software only; connection state and host data are local.
set -eu
. "$(dirname "$0")/../lib/common.sh"

brew_shellenv 2>/dev/null || true
have python3 || {
	warn "Python 3 is required for tssh — install it using your OS, then rerun."
	exit 1
}
have ssh || {
	warn "OpenSSH client missing — install it using your OS, then rerun."
	exit 1
}

# A CLI-only installation counts too: never add a second macOS variant.
if have tailscale || have tailscaled; then
	info "Keeping existing Tailscale installation and connection settings."
elif is_macos; then
	ensure_cask tailscale-app Tailscale.app || exit 1
elif is_linux; then
	ensure_cmd curl || exit 1
	info "Installing Tailscale with its official Linux installer..."
	run_remote_installer https://tailscale.com/install.sh || exit 1
else
	warn "unsupported platform ($(uname -s))"
	exit 1
fi

# Exclusive creation never overwrites existing files, including dangling
# symlinks. No host details come from the repository. Respect custom XDG homes.
python3 - <<'PY'
import os
from pathlib import Path

directory = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config') / 'tssh'
directory.mkdir(mode=0o700, parents=True, exist_ok=True)
try:
    fd = os.open(directory / 'hosts.json', os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
except FileExistsError:
    pass
else:
    with os.fdopen(fd, 'w') as config:
        config.write('{}\n')
print(f'Private SSH hosts (preserved on reinstall): {directory / "hosts.json"}')
PY

info "Authentication is manual: on Linux run sudo tailscale up; on macOS open Tailscale."
info "Choose GitHub at sign-in. Existing login, DNS, routes and service state are left alone."
