#!/usr/bin/env bash

set -e

# install tmux plugins
XDG_CONFIG_HOME=${XDG_ZCONFIG_HOME:-$HOME/.config}

TMUX_PLUGIN_DIR=$XDG_CONFIG_HOME/tmux/plugins

mkdir -p $TMUX_PLUGIN_DIR
git clone https://github.com/tmux-plugins/tmux-resurrect $TMUX_PLUGIN_DIR/tmux-resurrect
git clone https://github.com/tmux-plugins/tmux-continuum $TMUX_PLUGIN_DIR/tmux-continuum
git clone -b v2.1.1 https://github.com/catppuccin/tmux.git $TMUX_PLUGIN_DIR/catppuccin

echo "tmux plugins installed"
