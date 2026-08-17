# Grok Build Nix flake

Re-exports the `grok-build` package maintained by nixpkgs. The local flake
enables this unfree package itself, so installation needs no environment
variables or user-wide Nix configuration.

```sh
nix profile add path:$PWD#grok-build
```

Update with:

```sh
nix flake update
nix profile upgrade grok-build
```

The Grok release and artifact hashes are maintained by nixpkgs rather than in
this repository.
