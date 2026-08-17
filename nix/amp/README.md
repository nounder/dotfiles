# Amp Nix flake

Packages Amp as a normal Nix binary for macOS and Linux (`aarch64` and
`x86_64`).

```sh
nix run .
# or
nix profile add path:$PWD#amp
```

The release is fetched over certificate-validated HTTPS, fixed by SHA-256, and
verified at build time with Amp's pinned Minisign public key.

The flake pins a verified bootstrap binary in `/nix/store`. Amp cannot overwrite
that path, so `amp update` installs the new executable at `~/.amp/bin/amp`.
The package's `amp` trampoline (and `shell.sh`) prefer that copy, so the updater
changes the `amp` you actually run.

Refresh the pinned bootstrap with `./update.sh`, then `nix profile upgrade amp`
(or `nix/install.sh`). That only matters for a fresh install or after deleting
`~/.amp/bin/amp`.
