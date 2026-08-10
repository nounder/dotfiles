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

The binary runs directly from `/nix/store`. Amp detects this and does not try to
mutate the read-only store; its `amp update` command directs Nix installations
to use their package manager instead.
