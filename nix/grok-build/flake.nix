{
  description = "Grok Build CLI from nixpkgs";

  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";

  outputs =
    { self, nixpkgs, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
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
      packages = forAllSystems (system: {
        default = pkgsFor.${system}.grok-build;
        grok-build = pkgsFor.${system}.grok-build;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.grok-build}/bin/grok";
          meta.description = "Run Grok Build";
        };
      });

      formatter = forAllSystems (system: pkgsFor.${system}.nixfmt);
    };
}
