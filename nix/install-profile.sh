#!/bin/sh

set -eu

NIX_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
CHROMIUM_FLAKE="path:$NIX_DIR/ungoogled-chromium"
PROFILE_APP="$HOME/.nix-profile/Applications/Chromium.app"
USER_APP="$HOME/Applications/Ungoogled Chromium.app"
BACKUP_APP="$HOME/Applications/.Ungoogled Chromium.pre-nix.app"
LAUNCHER_ID="org.ungoogled-software.chromium.nix-launcher"

if ! command -v nix >/dev/null 2>&1; then
  echo "Nix is not installed; skipping Nix profile."
  exit 0
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Ungoogled Chromium profile is only available on macOS; skipping."
  exit 0
fi

if nix profile list --json 2>/dev/null | grep -q '"ungoogled-chromium"[[:space:]]*:'; then
  echo "Updating Ungoogled Chromium in the Nix profile..."
  nix profile upgrade ungoogled-chromium
else
  echo "Adding Ungoogled Chromium to the Nix profile..."
  nix profile install "$CHROMIUM_FLAKE#ungoogled-chromium"
fi

if [ ! -d "$PROFILE_APP" ]; then
  echo "Ungoogled Chromium was installed, but $PROFILE_APP is missing." >&2
  exit 1
fi

mkdir -p "$HOME/Applications"
if [ -L "$USER_APP" ] || [ -f "$USER_APP" ]; then
  rm "$USER_APP"
elif [ -d "$USER_APP" ]; then
  EXISTING_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
    "$USER_APP/Contents/Info.plist" 2>/dev/null || true)
  if [ "$EXISTING_ID" != "$LAUNCHER_ID" ]; then
    # Preserve an existing app rather than deleting it from an install script.
    if [ -e "$BACKUP_APP" ]; then
      echo "Cannot migrate $USER_APP: $BACKUP_APP already exists." >&2
      exit 1
    fi
    mv "$USER_APP" "$BACKUP_APP"
    echo "Moved the previous app bundle to $BACKUP_APP"
  fi
fi

# Build a small, normal macOS app bundle that launches the profile's browser.
# A Unix symlink or Finder alias gets a generic icon and does not look like an app.
BROWSER_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  "$PROFILE_APP/Contents/Info.plist")
mkdir -p "$USER_APP/Contents/MacOS" "$USER_APP/Contents/Resources"
LAUNCHER_ICON="$USER_APP/Contents/Resources/app.icns"
[ -e "$LAUNCHER_ICON" ] && chmod u+w "$LAUNCHER_ICON"
cp "$PROFILE_APP/Contents/Resources/app.icns" "$LAUNCHER_ICON"
chmod u+w "$LAUNCHER_ICON"
cat > "$USER_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Ungoogled Chromium</string>
  <key>CFBundleExecutable</key>
  <string>ungoogled-chromium-launcher</string>
  <key>CFBundleIconFile</key>
  <string>app.icns</string>
  <key>CFBundleIdentifier</key>
  <string>$LAUNCHER_ID</string>
  <key>CFBundleName</key>
  <string>Ungoogled Chromium</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$BROWSER_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BROWSER_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF
cat > "$USER_APP/Contents/MacOS/ungoogled-chromium-launcher" <<EOF
#!/bin/sh
exec "$PROFILE_APP/Contents/MacOS/Chromium" "\$@"
EOF
chmod +x "$USER_APP/Contents/MacOS/ungoogled-chromium-launcher"
/usr/bin/codesign --force --deep --sign - "$USER_APP" >/dev/null 2>&1

# Make the app immediately visible to Launch Services and Spotlight.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$USER_APP" >/dev/null 2>&1 || true
[ -x /usr/bin/mdimport ] && /usr/bin/mdimport "$USER_APP" >/dev/null 2>&1 || true

echo "Linked Ungoogled Chromium at $USER_APP"
