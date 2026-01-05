#!/usr/bin/env bash

if [[ -z "$ZELLIJ" ]]; then
    echo "not in zellij. doing nothing"
    exit 0
fi

path=$(fzf --height=100% --preview-window=noborder --no-separator --preview 'bat --color=always --wrap=never --style=plain {}')

zellij action toggle-floating-panes

if [[ -n "$path" ]]; then
    bytes=$(printf ":$1 $path\r:redraw\r" | od -An -tu1)
    zellij action write $bytes
fi
