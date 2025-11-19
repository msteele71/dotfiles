#!/usr/bin/env bash

# install tmux plugins
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

TMUX_PLUGIN_DIR=$XDG_CONFIG_HOME/tmux/plugins

mkdir -p $TMUX_PLUGIN_DIR

# tmux-resurrect
if [ -d "$TMUX_PLUGIN_DIR/tmux-resurrect" ]; then
  echo "updating tmux plugin tmux-resurrect"
  cd $TMUX_PLUGIN_DIR/tmux-resurrect && git pull
else
  git clone https://github.com/tmux-plugins/tmux-resurrect $TMUX_PLUGIN_DIR/tmux-resurrect
fi

# tmux-continuum
if [ -d "$TMUX_PLUGIN_DIR/tmux-continuum" ]; then
  echo "updating tmux plugin tmux-continuum"
  cd $TMUX_PLUGIN_DIR/tmux-continuum && git pull
else
  git clone https://github.com/tmux-plugins/tmux-continuum $TMUX_PLUGIN_DIR/tmux-continuum
fi

# catppuccin
if [ -d "$TMUX_PLUGIN_DIR/catppuccin" ]; then
  echo "tmux plugin catpuccin (branch v2.1.1) already cloned"
else
  git clone -b v2.1.1 https://github.com/catppuccin/tmux.git $TMUX_PLUGIN_DIR/catppuccin
fi

echo "tmux plugins installed"
