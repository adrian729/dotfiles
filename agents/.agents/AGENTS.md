# Paid model usage

Use free models for OpenCode delegation unless explicitly asked to use paid models, including through workflow instructions.

# Local shell configuration

Put machine-local shell customizations—PATH entries, aliases, environment variables, and app initialization—in `~/.local/.local_profile`. Do not put them in `.zshrc` or other dotfiles-managed shell files, or commit them to the dotfiles repo. Preserve existing local customizations during installation. Use `~/.local/bin` or `~/.local/scripts` for user executables.

# Releases

When I ask for a release of one of my projects (for example ducktape-laya), that request authorizes the project's whole documented release procedure end to end, including when a subagent runs it: creating and pushing release tags (`vX.Y.Z`, `bindings/go/vX.Y.Z`), creating the GitHub release, dispatching the attestation and publish workflows, and checking the registries. Stop only on the project's own stop rules (a failed gate, a byte mismatch), then report.
