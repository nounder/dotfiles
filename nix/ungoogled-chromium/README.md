# Ungoogled Chromium for macOS (Nix)

A Nix derivation for the official prebuilt macOS releases from
[`ungoogled-chromium-macos`](https://github.com/ungoogled-software/ungoogled-chromium-macos).
It supports Apple Silicon and Intel Macs.

## Install

It is installed automatically by the dotfiles `install.sh` when Nix is available.
To install or update the profile directly:

```sh
~/dotfiles/nix/install.sh
```

Launch it from the terminal:

```sh
ungoogled-chromium
```

Or open the app bundle:

```sh
open ~/.nix-profile/Applications/Chromium.app
```

The profile installer copies the signed `Chromium.app` to
`~/Applications/Chromium.app` and registers it with Launch Services and
Spotlight. Chromium cannot be launched from a trampoline that `exec`s the
browser binary: Launch Services keeps the trampoline's identity and Chromium
aborts with `EXC_BREAKPOINT` (`SIGTRAP`).

You can also run it without installing:

```sh
nix run .
```

## Use from another flake

Add this repository as an input, then include the package in your Home Manager or
nix-darwin package list:

```nix
inputs.ungoogled-chromium.url = "path:/path/to/dotfiles/nix/ungoogled-chromium";

# For example:
environment.systemPackages = [
  inputs.ungoogled-chromium.packages.${pkgs.system}.default
];
```

The browser is distributed as a native binary because building Chromium from source
is exceptionally expensive. The hashes pin both official architecture-specific DMGs.
