#!/usr/bin/env bash

tmp=$(mktemp)
yazi "$2" --chooser-file="$tmp"
paths=$(cat "$tmp" | while read -r; do printf "%q " "$REPLY"; done)
rm -f "$tmp"

if [[ -n "$paths" ]]; then
    zellij action toggle-floating-panes
    zellij action write-chars ":$1 $paths"
    zellij action write 13
else
    zellij action toggle-floating-panes
fi
