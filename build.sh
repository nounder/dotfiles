#!/bin/sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
TARGETS="aarch64-macos:darwin-arm64 aarch64-linux:linux-arm64 x86_64-linux:linux-amd64"

if ! command -v zig >/dev/null 2>&1; then
  echo "zig not found" >&2
  exit 1
fi

for zigfile in "$DIR"/bin/*.zig; do
  prog="$(basename "$zigfile" .zig)"
  echo "Building $prog..."
  for target in $TARGETS; do
    zig_target="${target%:*}"
    suffix="${target#*:}"
    zig build-exe "$DIR/bin/$prog.zig" -O ReleaseSmall -fstrip -fsingle-threaded -target "$zig_target" --name "$prog-$suffix"
    mv "$prog-$suffix" "$DIR/bin/"
  done
  rm -f "$prog"*.o
  echo "✓ $prog"
done
