# Tailscale and tssh

This package supports Linux and macOS. It stows `tssh` into
`~/.local/scripts`, which the shared zsh PATH already places before
`~/.local/bin` on both platforms. No extra aliases or shell edits are needed.

## Install

Use the root `./install.sh` and select `tailscale`, or install only this package
from the repository root:

```sh
stow --no-folding -R -t "$HOME" tailscale
bash tailscale/install.sh
```

Python 3 (3.8+) and the OpenSSH client must already be available. Missing
prerequisites are reported before Tailscale installation; this package does
not start a potentially lengthy Python build on Intel Macs.
The installer installs Tailscale only when missing. Linux uses the
[official installer](https://tailscale.com/docs/install/linux) for OS-level
integration. macOS uses `ensure_cask tailscale-app Tailscale.app` for the
[standalone app](https://tailscale.com/docs/concepts/macos-variants), preserving
an existing app (including App Store installations) or CLI-only installation.
An existing `tailscale` or `tailscaled` command is left alone. Installation
failures are reported rather than silently ignored.

On a new Linux machine, run `sudo tailscale up` yourself. On a new Mac, open
Tailscale, approve the extension if requested, and sign in. Choose **GitHub**.
For the macOS command line, enable CLI integration in Tailscale's settings;
see the [CLI documentation](https://tailscale.com/docs/reference/tailscale-cli?tab=macos).
The installer never signs in, switches accounts, connects or disconnects,
changes DNS/routes/SSH settings, or restarts an existing service. The official
Linux installer may start the service when installing Tailscale for the first time.

## Private host configuration

The installer creates an empty, owner-only regular file at
`${XDG_CONFIG_HOME:-$HOME/.config}/tssh/hosts.json` **only if absent**. Reinstalls
preserve its contents, permissions and symlinks. It is never stowed. Stow also
excludes it, and Git ignores an accidental copy in this package.

Add entries using `.config/tssh/hosts.example.json` as a reference. The example
contains placeholders only. Use a Tailscale IP or MagicDNS name as `address`.
All other fields are optional:

| Field | Purpose |
| --- | --- |
| `ssh_host` | Reuse a host alias from your private `~/.ssh/config`; defaults to the entry name |
| `user` | Override the SSH username |
| `port` | Override the SSH port |
| `identity_file` | Use a local private key path; the key stays outside this repo |
| `host_key_alias` | Check the existing known-host identity when changing the connection address |

`tssh` runs ordinary OpenSSH over Tailscale. The destination needs its SSH
server enabled. This does not enable the separate Tailscale SSH feature.
Normal OpenSSH host-key checks remain enabled. Existing SSH options, including
ProxyJump/ProxyCommand, are inherited from the chosen alias; use a separate
local alias if those options should differ for Tailscale.

```sh
tssh                  # Pick by name or number; q cancels
tssh example-server   # Connect by name
tssh -h               # --help
tssh -l               # --list
tssh -p example-server # --ping: check Tailscale connectivity without SSH
tssh -n example-server # --dry-run
tssh example-server hostname
```

Flags go before the host; arguments after the host are the remote command.
`-p` / `--ping` runs `tailscale ping` against the selected host's private
`address`, with up to three probes and a five-second timeout per probe. It may
finish early once a direct connection is found. Omit the host to pick one
interactively, or combine with `-n` to preview. Ping requires the Tailscale CLI
(enable CLI integration in the macOS app if needed). This tests the Tailscale
path; it does not check whether the SSH server is running or accepting logins.

For remote commands launched from a terminal, `tssh` closes remote stdin so
programs that read piped input do not wait indefinitely for keyboard EOF.
Actual pipes and redirected files are forwarded unchanged. Login sessions
(`tssh example-server` without a command) keep their normal interactive input.
Use `-i` / `--stdin` before the host to forward keyboard input to a command;
finish input with Ctrl-D. This does not allocate a remote terminal.

```sh
tssh example-server 'hostname'
printf '%s\n' 'hello from this machine' | tssh example-server 'cat'
tssh -i example-server 'cat'  # Forward keyboard input; Ctrl-D finishes
```

On a machine with custom `XDG_CONFIG_HOME`, the example still stows under
`~/.config/tssh`; the actual private config follows `XDG_CONFIG_HOME`.

Never commit real host inventories, usernames, tailnet names/IPs, SSH config,
keys, known hosts, auth keys or Tailscale state. Keep host files backed up
privately if you want to copy them between machines. Local shell customization
belongs in `~/.local/.local_profile` per the repo's zsh conventions.

To opt out on a machine, put `tailscale` in `.stow_blacklist.local`.
Restowing updates the script/example only. Neither restow nor uninstalling the
Stow links deletes the private host file or changes the Tailscale connection.
