#! /usr/bin/env bash

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

echo "Applying dofiles with chezmoi"
chezmoi apply
