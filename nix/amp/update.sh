#!/usr/bin/env bash
# Refresh sources.json to Amp's latest release (hashes + minisign signatures).
set -euo pipefail

DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
VERSION_URL="https://static.ampcode.com/cli/cli-version.txt"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "update.sh: need $1" >&2
    exit 1
  }
}

need curl
need nix
need python3

version=$(curl -fsSL "$VERSION_URL" | tr -d '[:space:]')
if [ -z "$version" ]; then
  echo "update.sh: empty version from $VERSION_URL" >&2
  exit 1
fi

echo "Pinning Amp $version"

python3 - "$DIR/sources.json" "$version" <<'PY'
import json
import subprocess
import sys
import urllib.request

out_path, version = sys.argv[1], sys.argv[2]
base = f"https://static.ampcode.com/cli/{version}"
systems = {
    "aarch64-darwin": "darwin-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-linux": "linux-x64-baseline",
}


def run(args):
    return subprocess.check_output(args, text=True).strip()


def prefetch(url):
    raw = run(["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url])
    return json.loads(raw)["hash"]


result = {"version": version, "systems": {}}
for system, target in systems.items():
    print(f"  {system} ({target})", file=sys.stderr)
    hex_hash = (
        urllib.request.urlopen(f"{base}/{target}-amp.sha256").read().decode().strip()
    )
    result["systems"][system] = {
        "target": target,
        "hash": run(["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", hex_hash]),
        "signatureHash": prefetch(f"{base}/amp-{target}.minisig"),
    }

with open(out_path, "w", encoding="utf-8") as fh:
    json.dump(result, fh, indent=2)
    fh.write("\n")
PY

echo "Wrote $DIR/sources.json"
echo "Apply with: nix profile upgrade amp"
