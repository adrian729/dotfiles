# macOS's /etc/zprofile runs path_helper between .zshenv and this file, which
# puts /usr/bin and friends back ahead of ~/.local/bin and Homebrew.
(( $+functions[_dotfiles_path] )) && _dotfiles_path --force
