{
  config,
  pkgs,
  fenix,
  unstable,
  ...
}:
let
  userName = config.userConfiguration.name;
  userFullName = config.userConfiguration.fullName;
  userEmail = config.userConfiguration.email;
  vls = unstable.callPackage ./vls.nix { };
in
{
  imports = [
    ./editors.nix
    ./virtualisation.nix
    ./claude-code.nix
  ];
  # git
  home-manager.users.${userName} = {
    programs = {
      git = {
        enable = true;
        settings.user.name = userFullName;
        settings.user.email = userEmail;
        settings.init = {
          defaultBranch = "main";
        };
      };
    };
  };
  programs.git.config = {
    init = {
      defaultBranch = "main";
    };
  };

  nixpkgs.overlays = [ fenix.overlays.default ];

  environment.systemPackages = with pkgs; [
    vls
    unstable.telegram-bot-api
    unstable.pnpm
    unstable.nodejs_24
    python313
    python313Packages.huggingface-hub
    git
    gcc
    unstable.bun
    unstable.playwright-mcp
    unstable.playwright-driver.browsers
    unstable.deno
    cloc
    postgresql_16
    lazygit
    typescript

    # unstable.claude-code
    unstable.aider-chat
    unstable.vlang
    unstable.lazysql
    unstable.sqlit-tui
    lazydocker
    pkgs.ansible

    uv
    cargo-watch
    mdbook
    mdbook-d2
    mdbook-pdf
    mdbook-pandoc
    d2
    nixfmt-tree
    (pkgs.fenix.stable.withComponents [
      "cargo"
      "clippy"
      "rust-src"
      "rustc"
      "rustfmt"
    ])
    pre-commit
    android-tools
  ];

  services.postgresql.package = pkgs.postgresql_17;
  services.pgadmin.enable = true;
  services.pgadmin.initialEmail = "test@mail.com";
  services.pgadmin.initialPasswordFile = "/etc/pgadminpassword";

}
