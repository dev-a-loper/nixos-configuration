{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.userConfiguration;

in
{
  options.userConfiguration = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable user configuration module.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "ehsan";
      description = "Username for the primary user account.";
      example = "alice";
    };

    fullName = lib.mkOption {
      type = lib.types.str;
      default = "Ehsan";
      description = "Full name for git and other applications.";
      example = "Alice Johnson";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "ehsan2003.2003.382@gmail.com";
      description = "Email address for git and other applications.";
      example = "alice@example.com";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "wheel"
        "networkmanager"
        "input"
      ];
      description = "Additional groups for the user account.";
    };

    hashedPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing hashed password (null to use secrets.HASHED_PASSWORD).";
    };

    persianLayout = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Persian keyboard layout.";
    };

    enablePraytimes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable praytimes service and waybar integration.";
    };

    # Secrets storage - imported from vars/secrets.<username>.nix and injected via flake.nix
    secrets = lib.mkOption {
      type = lib.types.submoduleWith {
        specialArgs = { };
        modules = [
          (
            { config, options, ... }:
            {
              options = {
                # User credentials
                HASHED_PASSWORD = lib.mkOption {
                  type = lib.types.str;
                  description = "Hashed password for the user account.";
                  example = "$y$j9T$...";
                };

                # Location for praytimes/redshift
                location = lib.mkOption {
                  type = lib.types.submodule {
                    options = {
                      latitude = lib.mkOption {
                        type = lib.types.float;
                        description = "Latitude coordinate for praytimes/redshift.";
                        example = 60;
                      };
                      longitude = lib.mkOption {
                        type = lib.types.float;
                        description = "Longitude coordinate for praytimes/redshift.";
                        example = 70;
                      };
                    };
                  };
                  description = "Geographic location for praytimes and redshift.";
                };

                # Taskwarrior sync
                taskwarrior-secret = lib.mkOption {
                  type = lib.types.str;
                  description = "Encryption secret for Taskwarrior sync (taskchampion).";
                  example = "Gaxmv3hthwsayri7...";
                };

                # VPN configurations
                awg-config = lib.mkOption {
                  type = lib.types.str;
                  description = "AmneziaVPN (WireGuard) configuration file content.";
                };

                openvpn = lib.mkOption {
                  type = lib.types.str;
                  description = "OpenVPN client configuration file content.";
                };
                wgconfig = lib.mkOption {
                  type = lib.types.anything;
                  description = "wireguard config for wg0";
                };

                # Proxy configurations
                proxies = lib.mkOption {
                  type = lib.types.anything;
                  description = "Attrset of proxy shell scripts. Each value is a shell script that launches the proxy (typically xray or sing-box).";
                  example = {
                    some-vless = "#!/bin/sh\nxray run -c ...";
                    name1 = "#!/bin/sh\nxray run -c ...";
                  };
                };

                defaultProxy = lib.mkOption {
                  type = lib.types.str;
                  description = "Name of the default proxy to use (must be a key in secrets.proxies).";
                  example = "some-vless";
                };

                # AI API keys
                OPENAI_API_KEY = lib.mkOption {
                  type = lib.types.str;
                  description = "OpenAI API key for AI services.";
                };

                OPENAI_API_HOST = lib.mkOption {
                  type = lib.types.str;
                  description = "OpenAI API host override.";
                  example = "https://api.openai.com/v1";
                };

                GROQ_API_KEY = lib.mkOption {
                  type = lib.types.str;
                  description = "Groq API key for AI services.";
                };

                OPENROUTER_API_KEY = lib.mkOption {
                  type = lib.types.str;
                  description = "OpenRouter API key for AI services.";
                };

                # Anthropic API settings
                ANTHROPIC_AUTH_TOKEN = lib.mkOption {
                  type = lib.types.str;
                  description = "Anthropic auth token for Claude/Anthropic API.";
                };

                ANTHROPIC_BASE_URL = lib.mkOption {
                  type = lib.types.str;
                  description = "Anthropic API base URL override.";
                  example = "https://api.anthropic.com";
                };

                # Telegram notification settings
                NOTIFIER_BOT_TOKEN = lib.mkOption {
                  type = lib.types.str;
                  description = "Telegram bot token for notifications.";
                };

                CHAT_ID = lib.mkOption {
                  type = lib.types.str;
                  description = "Telegram chat ID for notifications.";
                };

                # Freeform type to allow arbitrary additional attributes (e.g., individual proxy configs)
                _freeformOptions = lib.mkOption {
                  type = lib.types.attrsOf lib.types.anything;
                  description = "Additional arbitrary attributes (e.g., proxy configurations).";
                  internal = true;
                  default = { };
                };
              };
              # Enable freeform attributes
              freeformType = lib.types.attrsOf lib.types.anything;
            }
          )
        ];
      };
      description = "Secrets imported from vars/secrets file. Contains all sensitive configuration like passwords, API keys, VPN configs, etc.";
    };
  };

  config = lib.mkIf cfg.enable {
    # assertions
    assertions = [
      {
        assertion = cfg.name != "root";
        message = "userConfiguration.name cannot be 'root'.";
      }
      {
        assertion = builtins.match "^[a-z_][a-z0-9_-]*$" cfg.name != null;
        message = "userConfiguration.name must contain only lowercase letters, numbers, underscores, and hyphens, and must start with a letter or underscore.";
      }
    ];
  };
}
