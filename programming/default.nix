{
  config,
  pkgs,
  fenix,
  unstable,
  ...
}:
let
  aider-ce = unstable.callPackage ./aider-ce/package.nix { };
  userName = config.userConfiguration.name;
  userFullName = config.userConfiguration.fullName;
  userEmail = config.userConfiguration.email;
  secrets = config.userConfiguration.secrets;
in
{
  imports = [
    ./editors.nix
    ./virtualisation.nix
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

      claude-code = {
        enable = true;
        package = unstable.claude-code;
        settings = {
          env = {
            ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.7";
            ANTHROPIC_DEFAULT_SONNET_MODEL = "glm-4.7";
            ANTHROPIC_DEFAULT_OPUS_MODEL = "glm-5";
            # https_proxy = "http://localhost:1080";
            ANTHROPIC_AUTH_TOKEN = secrets.ANTHROPIC_AUTH_TOKEN;
            ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic";
          };
          hooks = {
            Notification = [
              {
                matcher = "*";
                hooks = [
                  {
                    type = "command";
                    command = "notify-send 'Claude Code' 'Awaiting your input'";
                  }
                ];
              }
              {
                matcher = "*";
                hooks = [
                  {
                    type = "command";
                    command = ''curl -s -X POST "https://api.telegram.org/bot${secrets.NOTIFIER_BOT_TOKEN}/sendMessage"  -d chat_id=${secrets.CHAT_ID}  -d text="claude is awaiting your input"'';
                  }
                ];
              }
            ];
          };
          alwaysThinkingEnabled = true;
        };
        mcpServers = {
          "web-search-prime" = {
            "type" = "http";
            "url" = "https://api.z.ai/api/mcp/web_search_prime/mcp";
            "headers" = {
              "Authorization" = "Bearer ${secrets.ANTHROPIC_AUTH_TOKEN}";
            };
          };

          "zai-mcp-server" = {
            "type" = "stdio";
            "command" = "npx";
            "args" = [
              "-y"
              "@z_ai/mcp-server"
            ];
            "env" = {
              "Z_AI_API_KEY" = "${secrets.ANTHROPIC_AUTH_TOKEN}";
              "Z_AI_MODE" = "ZAI";
            };
          };
          "web-reader" = {
            "type" = "http";
            "url" = "https://api.z.ai/api/mcp/web_reader/mcp";
            "headers" = {
              "Authorization" = "Bearer ${secrets.ANTHROPIC_AUTH_TOKEN}";
            };
          };
          "zread" = {
            "type" = "http";
            "url" = "https://api.z.ai/api/mcp/zread/mcp";
            "headers" = {
              "Authorization" = "Bearer ${secrets.ANTHROPIC_AUTH_TOKEN}";
            };
          };
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
    unstable.telegram-bot-api
    unstable.pnpm
    unstable.nodejs_24
    python310
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

    unstable.claude-code
    unstable.aider-chat # aider-ce
    unstable.vlang
    unstable.lazysql
    unstable.sqlit-tui
    lazydocker

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
  ];

  services.postgresql.package = pkgs.postgresql_17;
  services.pgadmin.enable = true;
  services.pgadmin.initialEmail = "test@mail.com";
  services.pgadmin.initialPasswordFile = "/etc/pgadminpassword";

}
