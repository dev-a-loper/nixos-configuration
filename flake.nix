{
  description = "Ehsan's system configuration";
  inputs = {
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "unstable";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";
    nix-alien.url = "github:thiagokokada/nix-alien";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
  outputs =
    {
      self,
      nixpkgs,
      nixvim,
      ...
    }@inputs:
    let
      nixvim' = nixvim.legacyPackages.${system};
      nvim = nixvim'.makeNixvimWithModule {
        pkgs = inputs.unstable.legacyPackages.${system};
        module = import ./programming/nixvim;
      };
      system = "x86_64-linux";
      secrets-file = ./vars/secrets.ehsan.nix;
      secrets = import secrets-file;
      hardware-configuration = ./vars/hardware-configuration.nix;
      system-definer = (
        secrets: hw:
        let
          specialArgs = inputs // {
            unstable = import inputs.unstable {
              inherit system;
              config.allowUnfree = true;
            };
            hardware-configuration = hw;
            llm-agents = inputs.llm-agents.packages.${system};
            caelestia-shell = inputs.caelestia-shell;
          };
          # Module to inject secrets into config.userConfiguration.secrets
          secretsModule =
            { config, ... }:
            {
              config.userConfiguration.secrets = secrets;
            };
        in
        {
          base = {
            inherit specialArgs system;
            modules = [
              secretsModule
              ./hosts/base.nix
            ];
          };

          nixos-new-laptop = {
            inherit specialArgs system;
            modules = [
              secretsModule
              ./hosts/new-laptop.nix
            ];
          };

          nixos-laptop = {
            inherit specialArgs system;
            modules = [
              secretsModule
              ./hosts/laptop.nix
            ];
          };
          nixos-home-desktop = {
            inherit specialArgs system;
            modules = [
              secretsModule
              ./hosts/home-pc.nix
            ];
          };

          tablet = {
            inherit specialArgs system;
            modules = [
              secretsModule
              ./hosts/tablet.nix
            ];
          };

          usb = {
            inherit specialArgs system;
            modules = [
              secretsModule
              ./hosts/usb.nix
            ];
          };
          iso = {
            inherit specialArgs system;
            modules = [
              secretsModule
              ./hosts/iso.nix
            ];
          };
        }
      );
    in
    {
      packages."x86_64-linux".nvim = nvim;
      packages."x86_64-linux".iso = inputs.self.nixosConfigurations.iso.config.system.build.isoImage;
      packages."x86_64-linux".usb = inputs.self.nixosConfigurations.usb.config.system.build.sdImage;
      nixosConfigurations = builtins.mapAttrs (name: value: (nixpkgs.lib.nixosSystem value)) (
        system-definer secrets hardware-configuration
      );
      inherit system-definer;
    };
}
