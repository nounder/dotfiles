#!/bin/sh

# Install extra tools interactively
# Usage: install-extra.sh [-f]   (-f prompts even if already installed)
# First collects all answers, then installs selected tools.

force=0
if [ "$1" = "-f" ]; then
  force=1
fi

# Pending installs: space-separated "name|cmd" pairs (cmd may contain spaces)
pending=""

queue_install() {
  local name="$1"
  local bin="$2"
  local cmd="$3"
  if [ "$force" -eq 0 ] && command -v "$bin" >/dev/null 2>&1; then
    echo "$name already installed"
    return
  fi
  printf "Install %s? [y/N] " "$name"
  read -r answer
  case "$answer" in
    [yY]*)
      pending="$pending
$name|$cmd"
      ;;
    *) echo "Skipping $name" ;;
  esac
}

arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "Unsupported arch: $(uname -m)" >&2; return 1 ;;
  esac
}

install_neovim_appimage() {
  mkdir -p "$HOME/.local/bin"
  curl -L -o "$HOME/.local/bin/nvim" "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$(arch).appimage" || return 1
  chmod u+x "$HOME/.local/bin/nvim"
}

# --- prompts ---
queue_install "Claude Code" "claude" "bun install --global @anthropic-ai/claude-code"
queue_install "Codex" "codex" "bun install --global @openai/codex"

if [ "$(uname -s)" = "Linux" ]; then
  queue_install "Neovim (AppImage)" "nvim" "install_neovim_appimage"
fi

# --- install ---
if [ -z "$(printf '%s' "$pending" | tr -d '\n')" ]; then
  echo "Nothing to install."
  exit 0
fi

echo
echo "Installing..."
printf '%s\n' "$pending" | while IFS= read -r line; do
  [ -z "$line" ] && continue
  name="${line%%|*}"
  cmd="${line#*|}"
  echo "==> $name"
  eval "$cmd" || echo "Failed: $name"
done
