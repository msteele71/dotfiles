#! /usr/bin/env bash

mkdir -p ~/.config/chezmoi
jq -n --arg source "~/.config/coderv2/dotfiles" '{"sourceDir": $source}' > ~/.config/chezmoi/chezmoi.json
chezmoi apply
