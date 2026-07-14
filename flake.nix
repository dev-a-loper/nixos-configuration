{
  description = "Ehsan's system configuration (self-contained, specialisation-driven)";
  inputs = {
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
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
    nur.inputs.nixpkgs.follows = "unstable";
    nix-alien.url = "github:thiagokokada/nix-alien";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";

    HyprQuickFrame.url = "github:Ronin-CK/HyprQuickFrame";
    HyprQuickFrame.inputs.nixpkgs.follows = "nixpkgs";
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
      system = "x86_64-linux";
      nixvim' = nixvim.legacyPackages.${system};
      nvim = nixvim'.makeNixvimWithModule {
        pkgs = inputs.unstable.legacyPackages.${system};
        module = import ./programming/nixvim;
      };

      hardware-configuration = ./vars/hardware-configuration.nix;
      # Boot parent: shared infra + Ehsan's profile. Every host boots into this.
      defaultSecrets = ./vars/secrets.default.nix;

      # ── profile auto-discovery ───────────────────────────────────────────
      # Each vars/secrets.<name>.nix (except `default`) becomes a runtime-
      # switchable `specialisation.<name>`. The profile module overrides only
      # what differs from the parent (see secrets.*.nix). readDir sees the
      # gitignored secrets because the flake is accessed via the `path:` fetcher
      # (build with `path:.` / --impure) — the same reason hardware-configuration
      # and the secrets already evaluate today.
      profileSecrets =
        let
          dir = ./vars;
          matchName = builtins.match "secrets\\.([^.]+)\\.nix";
          isProfile = f: f != "secrets.default.nix" && matchName f != null;
        in
        builtins.map (f: {
          name = builtins.head (matchName f);
          file = dir + "/${f}";
        }) (builtins.filter isProfile (builtins.attrNames (builtins.readDir dir)));

      # One specialisation per profile, each inheriting the parent config and
      # layering the profile's overrides on top.
      specialisations = builtins.listToAttrs (
        builtins.map (p: {
          name = p.name;
          value = {
            inheritParentConfig = true;
            configuration.imports = [ p.file ];
          };
        }) profileSecrets
      );

      specialArgs = inputs // {
        HyprQuickFrame = inputs.HyprQuickFrame.packages.${system}.default;
        unstable = import inputs.unstable {
          inherit system;
          config.allowUnfree = true;
        };
        inherit hardware-configuration;
        llm-agents = inputs.llm-agents.packages.${system};
      };

      # Each host shares the same shape: specialArgs + system + the default
      # secrets module next to its host module (./hosts/<host>.nix), plus the
      # auto-generated specialisations.
      makeConfig = host: {
        inherit specialArgs system;
        modules = [
          defaultSecrets
          ./hosts/${host}.nix
          { specialisation = specialisations; }
        ];
      };
    in
    {
      packages."x86_64-linux".nvim = nvim;
      packages."x86_64-linux".iso = self.nixosConfigurations.iso.config.system.build.isoImage;
      packages."x86_64-linux".usb = self.nixosConfigurations.usb.config.system.build.sdImage;
      nixosConfigurations = builtins.mapAttrs (_: nixpkgs.lib.nixosSystem) {
        base = makeConfig "base";
        nixos-new-laptop = makeConfig "new-laptop";
        nixos-laptop = makeConfig "laptop";
        nixos-home-desktop = makeConfig "home-pc";
        tablet = makeConfig "tablet";
        usb = makeConfig "usb";
        iso = makeConfig "iso";
      };
    };
}
