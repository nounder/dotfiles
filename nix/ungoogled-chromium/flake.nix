{
  description = "Ungoogled Chromium for macOS";

  # 26.05 is the final nixpkgs release with Intel macOS support.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

  outputs =
    { self, nixpkgs, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          package = pkgs.callPackage ./package.nix { };
        in
        {
          default = package;
          ungoogled-chromium = package;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/ungoogled-chromium";
          meta.description = "Run Ungoogled Chromium";
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
