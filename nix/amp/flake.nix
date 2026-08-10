{
  description = "Amp CLI, verified with Amp's pinned Minisign release key";

  # 26.05 is the final nixpkgs release with Intel macOS support.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

  outputs =
    { self, nixpkgs, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          package = pkgsFor.${system}.callPackage ./package.nix { };
        in
        {
          default = package;
          amp = package;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.amp}/bin/amp";
          meta.description = "Run Amp";
        };
      });

      formatter = forAllSystems (system: pkgsFor.${system}.nixfmt);
    };
}
