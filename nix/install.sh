#!/bin/sh

set -eu

NIX_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
AMP_FLAKE="path:$NIX_DIR/amp"
GROK_BUILD_FLAKE="path:$NIX_DIR/grok-build"
GHOSTTY_PACKAGE="nixpkgs#ghostty-bin"
CHROMIUM_FLAKE="path:$NIX_DIR/ungoogled-chromium"
PROFILE_GHOSTTY_APP="$HOME/.nix-profile/Applications/Ghostty.app"
USER_GHOSTTY_APP="$HOME/Applications/Ghostty.app"
GHOSTTY_BACKUP_APP="$HOME/Applications/.Ghostty.pre-nix.app"
GHOSTTY_MARKER="$HOME/Applications/.Ghostty.nix-managed"
PROFILE_APP="$HOME/.nix-profile/Applications/Chromium.app"
USER_APP="$HOME/Applications/Chromium.app"
BACKUP_APP="$HOME/Applications/.Chromium.pre-nix.app"
CHROMIUM_MARKER="$HOME/Applications/.Chromium.nix-managed"
# Older installs used a differently named copy or a trampoline app.
OLD_USER_APP="$HOME/Applications/Ungoogled Chromium.app"
OLD_CHROMIUM_MARKER="$HOME/Applications/.Ungoogled-Chromium.nix-managed"
OLD_LAUNCHER_ID="org.ungoogled-software.chromium.nix-launcher"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if ! command -v nix >/dev/null 2>&1; then
  echo "Nix is not installed; skipping Nix profile."
  exit 0
fi

if nix profile list --json 2>/dev/null | grep -q '"amp"[[:space:]]*:'; then
  echo "Updating Amp in the Nix profile..."
  nix profile upgrade amp
else
  echo "Adding Amp to the Nix profile..."
  nix profile add "$AMP_FLAKE#amp"
fi

PROFILE_JSON=$(nix profile list --json 2>/dev/null)
if printf '%s' "$PROFILE_JSON" | grep -q '"grok-build"[[:space:]]*:'; then
  if printf '%s' "$PROFILE_JSON" | grep -Fq "\"originalUrl\":\"$GROK_BUILD_FLAKE\""; then
    echo "Updating Grok Build in the Nix profile..."
    nix profile upgrade grok-build
  else
    # Migrate installations added directly from nixpkgs. Their original source
    # does not inherit this flake's allowUnfree setting during profile upgrades.
    echo "Migrating Grok Build to the local Nix flake..."
    nix build --no-link "$GROK_BUILD_FLAKE#grok-build"
    nix profile remove grok-build
    nix profile add "$GROK_BUILD_FLAKE#grok-build"
  fi
else
  echo "Adding Grok Build to the Nix profile..."
  nix profile add "$GROK_BUILD_FLAKE#grok-build"
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Ghostty and Ungoogled Chromium profiles are only available on macOS; skipping."
  exit 0
fi

if nix profile list --json 2>/dev/null | grep -q '"ghostty-bin"[[:space:]]*:'; then
  echo "Updating Ghostty in the Nix profile..."
  nix profile upgrade ghostty-bin
else
  echo "Adding Ghostty to the Nix profile..."
  nix profile add "$GHOSTTY_PACKAGE"
fi

if [ ! -d "$PROFILE_GHOSTTY_APP" ]; then
  echo "Ghostty was installed, but $PROFILE_GHOSTTY_APP is missing." >&2
  exit 1
fi

# Profile Applications are outside Spotlight's normal search locations. Copy the
# signed upstream bundle into ~/Applications so Spotlight and Launch Services see it.
mkdir -p "$HOME/Applications"
if [ -e "$USER_GHOSTTY_APP" ] || [ -L "$USER_GHOSTTY_APP" ]; then
  if [ ! -e "$GHOSTTY_MARKER" ]; then
    # Preserve a Ghostty installation that was not created by this script.
    if [ -e "$GHOSTTY_BACKUP_APP" ] || [ -L "$GHOSTTY_BACKUP_APP" ]; then
      echo "Cannot migrate $USER_GHOSTTY_APP: $GHOSTTY_BACKUP_APP already exists." >&2
      exit 1
    fi
    mv "$USER_GHOSTTY_APP" "$GHOSTTY_BACKUP_APP"
    echo "Moved the previous app bundle to $GHOSTTY_BACKUP_APP"
  else
    chmod -R u+w "$USER_GHOSTTY_APP" 2>/dev/null || true
    rm -rf "$USER_GHOSTTY_APP"
  fi
fi
/usr/bin/ditto "$PROFILE_GHOSTTY_APP" "$USER_GHOSTTY_APP"
touch "$GHOSTTY_MARKER"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$USER_GHOSTTY_APP" >/dev/null 2>&1 || true
[ -x /usr/bin/mdimport ] && /usr/bin/mdimport "$USER_GHOSTTY_APP" >/dev/null 2>&1 || true
echo "Installed Ghostty at $USER_GHOSTTY_APP"

if nix profile list --json 2>/dev/null | grep -q '"ungoogled-chromium"[[:space:]]*:'; then
  echo "Updating Ungoogled Chromium in the Nix profile..."
  nix profile upgrade ungoogled-chromium
else
  echo "Adding Ungoogled Chromium to the Nix profile..."
  nix profile add "$CHROMIUM_FLAKE#ungoogled-chromium"
fi

if [ ! -d "$PROFILE_APP" ]; then
  echo "Ungoogled Chromium was installed, but $PROFILE_APP is missing." >&2
  exit 1
fi

# Chromium CHECKs (SIGTRAP) if a trampoline .app execs the browser binary.
# Launch Services keeps the trampoline's identity after exec, so helper
# lookup and the outer bundle no longer match. Copy the signed upstream
# bundle into ~/Applications, same as Ghostty.
mkdir -p "$HOME/Applications"
if [ -e "$OLD_USER_APP" ] || [ -L "$OLD_USER_APP" ]; then
  chmod -R u+w "$OLD_USER_APP" 2>/dev/null || true
  rm -rf "$OLD_USER_APP"
fi
rm -f "$OLD_CHROMIUM_MARKER"
if [ -e "$USER_APP" ] || [ -L "$USER_APP" ]; then
  EXISTING_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
    "$USER_APP/Contents/Info.plist" 2>/dev/null || true)
  if [ -e "$CHROMIUM_MARKER" ] || [ "$EXISTING_ID" = "$OLD_LAUNCHER_ID" ]; then
    chmod -R u+w "$USER_APP" 2>/dev/null || true
    rm -rf "$USER_APP"
  else
    # Preserve an existing app rather than deleting it from an install script.
    if [ -e "$BACKUP_APP" ] || [ -L "$BACKUP_APP" ]; then
      echo "Cannot migrate $USER_APP: $BACKUP_APP already exists." >&2
      exit 1
    fi
    mv "$USER_APP" "$BACKUP_APP"
    echo "Moved the previous app bundle to $BACKUP_APP"
  fi
fi
/usr/bin/ditto "$PROFILE_APP" "$USER_APP"
touch "$CHROMIUM_MARKER"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$USER_APP" >/dev/null 2>&1 || true
[ -x /usr/bin/mdimport ] && /usr/bin/mdimport "$USER_APP" >/dev/null 2>&1 || true
echo "Installed Chromium at $USER_APP"
