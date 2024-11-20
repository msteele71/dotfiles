#! /usr/bin/env bash

##
# This setup file serves two main purposes
# 1. Perform any FTR setup to prepare for actually applying dotfiles
# 2. Applying/Running the dotfiles setup, in this case using chezmoi
##

CODER_DOTFILES=$HOME/.config/coderv2/dotfiles
CHEZMOI_CONFIG=$HOME/.config/chezmoi/chezmoi.json

# first configure chezmoi to use the coder dotfiles src directory
mkdir -p ~/.config/chezmoi

#create default config if non exists
if [ ! -f "$CHEZMOI_CONFIG" ]; then
    jq -n '{}' > $CHEZMOI_CONFIG
fi
# set the sourceDir value
echo "Setting sourceDir value for chezmoi config: $CODER_DOTFILES"
jq --arg source $CODER_DOTFILES \
    '.sourceDir = $source' \
    $CHEZMOI_CONFIG > /tmp/chezmoi.config && mv /tmp/chezmoi.config $CHEZMOI_CONFIG

# next link the metadata.json so that chezmoi can read it
if [ -f "$HOME/.vworkstation/metadata.json" ] && [ ! -f "$CODER_DOTFILES/.chezmoidata/vworkstation.json" ]; then
    # ensure the data dir exists
    mkdir -p $CODER_DOTFILES/.chezmoidata
    ln -s $HOME/.vworkstation/metadata.json $CODER_DOTFILES/.chezmoidata/vworkstation.json
fi

echo "Applying dotfiles with chezmoi"
chezmoi apply

# run scripts created from templates by chezmoi apply
# template: dot_vworkstation/executable_init_root.sh.tmpl
echo "Setting up root volume with user env"
$HOME/.vworkstation/init_root.sh
# template: dot_vworkstation/executable_init_home.sh.tmpl
echo "Setting up home volume with user env"
$HOME/.vworkstation/init_home.sh
date