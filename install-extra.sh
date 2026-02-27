#!/bin/sh

# Install extra tools interactively

ask_install() {
  local name="$1"
  local cmd="$2"
  printf "Install %s? [y/N] " "$name"
  read -r answer
  case "$answer" in
    [yY]*) eval "$cmd" ;;
    *) echo "Skipping $name" ;;
  esac
}

ask_install "Claude Code" "bun install --global @anthropic-ai/claude-code"
ask_install "Codex" "bun install --global @openai/codex"
