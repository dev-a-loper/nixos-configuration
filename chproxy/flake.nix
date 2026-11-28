{
  description = "chproxy — sing-box switcher: templates + carriers, tunneling decoupled (package + NixOS module)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs.lib) genAttrs;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = genAttrs systems;

      # ── packages ──────────────────────────────────────────────────────────
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          sing-box-extended = pkgs.callPackage ./sing-box-extended.nix { };
          chproxy = pkgs.callPackage ./package.nix { sing-box = sing-box-extended; };
        in
        {
          inherit chproxy sing-box-extended;
          default = chproxy;
        }
      );

      # ── NixOS module ──────────────────────────────────────────────────────
      # `src` is the flake's own source. The module builds its packages from
      # it with the HOST's pkgs (the importer's nixpkgs), so a consumer that
      # makes this input follow its own nixpkgs gets one coherent sing-box.
      nixosModules = rec {
        chproxy = import ./nixos { src = ./.; };
        default = chproxy;
      };
    in
    {
      inherit packages nixosModules;

      # Minimal, buildable reference configuration — also the module's test.
      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          ./example/configuration.nix
        ];
      };

      checks.x86_64-linux = {
        package = self.packages.x86_64-linux.default;
        module = self.nixosConfigurations.example.config.system.build.toplevel;
      };
    };
}
