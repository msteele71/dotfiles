#! /usr/bin/env bash

##
# This setup file acts as a dotfile manager proxy for the coder dotfiles process.
# Why? The coder dotfiles command clones the repo and then either executes
# a script OR will copy everything into the $HOME directory.  NOT BOTH!
# So if you want to use a dotfile manager then you need to have a setup
# script handle calling the dotfile manager.
#
# The script below sets up chezmoi as the dotfile manager.  This script will
# proxy the call from coder for the setup script, delegating setup to chezmoi.
##

# this is where the coder dotfiles command puts the dotfiles
CODER_DOTFILES=$HOME/.config/coderv2/dotfiles

# check if the dotfiles directory exists
if [ ! -d "$CODER_DOTFILES" ]; then
    echo "WARNING: The CODER_DOTFILES directory does not exist: $CODER_DOTFILES"
    echo "This script should only be used if the dotfiles are setup with _coder dotfiles_"
    echo "Otherwise, use your normal dotfile manager to apply changes."
    exit 1
fi

# this is the configuration file that chezmoi will look for
CHEZMOI_CONFIG=$HOME/.config/chezmoi/chezmoi.json

# first configure chezmoi to use the coder dotfiles src directory
mkdir -p ~/.config/chezmoi

#create default config if non exists
if [ ! -f "$CHEZMOI_CONFIG" ]; then
    jq -n '{}' > $CHEZMOI_CONFIG
fi

# set the sourceDir value so that chezmoi will find the coder specific
# location where the dotfiles are cloned
echo "Setting sourceDir value for chezmoi config: $CODER_DOTFILES"
    jq --arg source $CODER_DOTFILES \
      '.sourceDir = $source' \
      $CHEZMOI_CONFIG > /tmp/chezmoi.config && mv /tmp/chezmoi.config $CHEZMOI_CONFIG

# next link any metadata json so that chezmoi can read it
if [ -f "$HOME/.config/deepgram/metadata.json" ] && [ ! -f "$CODER_DOTFILES/.chezmoidata/coder-instance.json" ]; then
    # ensure the data dir exists
    mkdir -p $CODER_DOTFILES/.chezmoidata
    ln -s $HOME/.config/deepgram/metadata.json $CODER_DOTFILES/.chezmoidata/coder-instance.json
fi

# Set all env vars jic
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export XDG_CACHE_HOME=$HOME/.cache

echo "Applying dotfiles with chezmoi"
chezmoi apply

date