# Paid model usage

Use free models for OpenCode delegation unless explicitly asked to use paid models, including through workflow instructions.

# Local shell configuration

Put machine-local shell customizations—PATH entries, aliases, environment variables, and app initialization—in `~/.local/.local_profile`. Do not put them in `.zshrc` or other dotfiles-managed shell files, or commit them to the dotfiles repo. Preserve existing local customizations during installation. Use `~/.local/bin` or `~/.local/scripts` for user executables.
