#!/bin/sh

# Get the absolute path to the dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# if -f option is passed, force symlink
if [ "$1" = "-f" ]; then
  LN_OPTS="-f"
else
  LN_OPTS=""
fi

mkdir -p ~/.config

cd ~/.config

ln -s $LN_OPTS "$DOTFILES_DIR/kitty/" kitty

ln -s $LN_OPTS "$DOTFILES_DIR/fish/" fish

ln -s $LN_OPTS "$DOTFILES_DIR/helix/" helix

ln -s $LN_OPTS "$DOTFILES_DIR/nvim/" nvim

ln -s $LN_OPTS "$DOTFILES_DIR/ghostty/" ghostty

ln -s $LN_OPTS "$DOTFILES_DIR/tmux.conf" .tmux.conf

mkdir -p direnv
ln -s $LN_OPTS "$DOTFILES_DIR/direnv.toml" direnv/direnv.toml
