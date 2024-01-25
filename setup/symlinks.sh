#!/bin/bash
# symlinks.sh
# Removes default config files/folders and sets up symlinks to replace them.

DIR=$HOME/.dotfiles
CONFIG_DIR=$HOME/.config

HOME_DOTFILES=(

)
CONFIG_DOTFILES=(
	"nvim"
)
for dotfile in "${HOME_DOTFILES[@]}"; do
	rm -rfv "${HOME}/${dotfile}"
	ln -sfv "${DIR}/${dotfile}" "${HOME}"
done

for dotfile in "${CONFIG_DOTFILES[@]}"; do
	rm -rfv "${CONFIG_DIR}/${dotfile}"
	ln -sfv "${DIR}/${dotfile}" "${CONFIG_DIR}"
done
