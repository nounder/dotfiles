#!/bin/sh

# Get the absolute path to the dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# if -f option is passed, force symlink
if [ "$1" = "-f" ]; then
  LN_OPTS="-f"
else
  LN_OPTS=""
fi

CONFIG="$HOME/.config"

mkdir -p $CONFIG

safe_link() {
  local source="$1"
  local target="$2"

  # With -f, force overwrite even if target is a regular file
  if [ -n "$LN_OPTS" ]; then
    rm -rf "$target" 2>/dev/null
    ln -s "$source" "$target"
    return
  fi

  # Skip if target exists and is not a symlink
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "⚠ $(basename "$target") exists - skipping"
    return
  fi

  # Remove existing symlink
  [ -L "$target" ] && rm "$target"

  # Create new symlink
  ln -s "$source" "$target"
}

safe_link "$DOTFILES_DIR/kitty" "$CONFIG/kitty"
safe_link "$DOTFILES_DIR/fish" "$CONFIG/fish"
safe_link "$DOTFILES_DIR/helix" "$CONFIG/helix"
safe_link "$DOTFILES_DIR/nvim" "$CONFIG/nvim"
safe_link "$DOTFILES_DIR/ghostty" "$CONFIG/ghostty"
safe_link "$DOTFILES_DIR/opencode" "$CONFIG/opencode"
safe_link "$DOTFILES_DIR/nushell" "$CONFIG/nushell"
safe_link "$DOTFILES_DIR/lazygit" "$CONFIG/lazygit"

safe_link "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf"

mkdir -p "$CONFIG/direnv"
safe_link "$DOTFILES_DIR/direnv.toml" "$CONFIG/direnv/direnv.toml"

mkdir -p "$HOME/.claude"
safe_link "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"
safe_link "$DOTFILES_DIR/claude/commands" "$HOME/.claude/commands"

# Install launch agent only if LaunchAgents directory exists
if [ -d "$HOME/Library/LaunchAgents" ]; then
  if [ -f "$DOTFILES_DIR/org.libred.kbdcmd.plist" ]; then
    cp "$DOTFILES_DIR/org.libred.kbdcmd.plist" "$HOME/Library/LaunchAgents/org.libred.kbdcmd.plist"
    launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/org.libred.kbdcmd.plist"
  fi
fi

if [ -f "$HOME/.ssh/config" ] && ! grep -q "Include.*dotfiles/ssh/config" "$HOME/.ssh/config" 2>/dev/null; then
  echo "Include ~/dotfiles/ssh/config" >> "$HOME/.ssh/config"
fi

safe_link "$DOTFILES_DIR/home-fdignore" "$HOME/.fdignore"

if [ -z "$LN_OPTS" ] && [ -n "$(git config --global core.attributesfile)" ]; then
  echo "⚠ core.attributesfile exists - skipping"
else
  git config --global core.attributesfile "$DOTFILES_DIR/gitattributes"
fi
