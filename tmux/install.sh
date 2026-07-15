#!/bin/bash

command -v tmux &>/dev/null || brew install tmux

if [ ! -d ~/.tmux/plugins/tpm ]; then
	echo "Cloning TPM..."
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi
