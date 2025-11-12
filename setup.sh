#! /usr/bin/env bash

##
# This setup file serves two main purposes
# 1. Perform any FTR setup to prepare for actually applying dotfiles
# 2. Applying/Running the dotfiles setup, in this case using chezmoi
##

CHEZMOI_CONFIG=$HOME/.config/chezmoi/chezmoi.json

# first configure chezmoi to use the coder dotfiles src directory
mkdir -p ~/.config/chezmoi

#create default config if non exists
if [ ! -f "$CHEZMOI_CONFIG" ]; then
    jq -n '{}' > $CHEZMOI_CONFIG
fi

# set the sourceDir value
# echo "Setting sourceDir value for chezmoi config: $CODER_DOTFILES"
# jq --arg source $CODER_DOTFILES \
#     '.sourceDir = $source' \
#     $CHEZMOI_CONFIG > /tmp/chezmoi.config && mv /tmp/chezmoi.config $CHEZMOI_CONFIG

# # next link the metadata.json so that chezmoi can read it
# if [ -f "$HOME/.vworkstation/metadata.json" ] && [ ! -f "$CODER_DOTFILES/.chezmoidata/vworkstation.json" ]; then
#     # ensure the data dir exists
#     mkdir -p $CODER_DOTFILES/.chezmoidata
#     ln -s $HOME/.vworkstation/metadata.json $CODER_DOTFILES/.chezmoidata/vworkstation.json
# fi

# Set all env vars
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export XDG_CACHE_HOME=$HOME/.cache

echo "Applying dotfiles with chezmoi"
chezmoi apply

date