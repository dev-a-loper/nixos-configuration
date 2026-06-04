{
  config,
  pkgs,
  nix-alien,
  unstable,
  llm-agents,
  ...
}:
let
  urls = (import ./uri-short.nix pkgs);
  secrets = config.userConfiguration.secrets;
  alert = (import ./alert.nix pkgs) secrets;
  pgbkp = pkgs.callPackage ./pgbkp/default.nix { postgresql = pkgs.postgresql_16; };
  userName = config.userConfiguration.name;
in
{
  imports = [ ];

  environment.shells = with pkgs; [ zsh ];
  users.defaultUserShell = pkgs.zsh;
  # $ nix search wget
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  services.atd.enable = true;
  environment.variables.OPENAI_API_KEY = secrets.OPENAI_API_KEY;
  environment.variables.GROQ_API_KEY = secrets.GROQ_API_KEY;
  environment.variables.OPENAI_API_HOST = secrets.OPENAI_API_HOST;
  environment.variables.OPENROUTER_API_KEY = secrets.OPENROUTER_API_KEY;

  environment.variables.ANTHROPIC_AUTH_TOKEN = secrets.ANTHROPIC_AUTH_TOKEN;
  environment.variables.ANTHROPIC_BASE_URL = secrets.ANTHROPIC_BASE_URL;
  environment.variables.ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-5.1";
  environment.variables.ANTHROPIC_DEFAULT_SONNET_MODEL = "glm-5.1";
  environment.variables.ANTHROPIC_DEFAULT_OPUS_MODEL = "glm-5.1";

  home-manager.users.${userName} = {
    programs.taskwarrior = {
      enable = true;
      package = pkgs.taskwarrior3;
      config = {
        sync.encryption_secret = secrets.taskwarrior-secret;
        sync.server.client_id = "aa529e36-0e93-4d5a-90e4-921f942aa0d7";
        sync.server.origin = "http://localhost:8443";
      };
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    home.file.timewarrior-hook = {
      executable = true;
      source = "${pkgs.timewarrior}/share/doc/timew/ext/on-modify.timewarrior";
      target = ".local/share/task/hooks/on-modify.timewarrior";
    };

  };

  environment.shellAliases.z = "zoxide";

  environment.systemPackages =
    (with pkgs; [
      # editors
      vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
      openssl
      llm-agents.claude-agent-acp
      (pkgs.writeShellScriptBin "claude-code-acp" "${llm-agents.claude-agent-acp}/bin/claude-agent-acp")
      llm-agents.claude-plugins
      llm-agents.skills-installer

      # Netowrk
      wget
      curl
      aria2
      caddy
      alert
      # Absolute Utils
      nix-tree
      killall
      btop
      unrar-wrapper
      unzip
      ripgrep
      sd
      fd
      bat
      jcal
      jq
      ddgr
      pup
      tmux
      v4l-utils
      github-cli
      aichat
      nethogs
      wl-clipboard
      zip
      tree
      ncdu
      imagemagick
      chntpw
      zellij
      timewarrior
      lynx
      zoxide
      yazi
      certbot
      lm_sensors
      (pkgs.writeShellApplication {
        name = "ai";
        text = ''${alacritty}/bin/alacritty --title "aider" '';
      })
      pgbkp
    ])
    ++ [
      nix-alien.packages.${"x86_64-linux"}.nix-alien
      (urls "mathcha" "https://mathcha.io/editor")
      (urls "poe" "https://poe.com")
      (urls "meet" "https://meet.google.com/")
      # (urls "claude" "https://claude.ai/")

    ];
  programs.zsh.enable = true;
  programs.zsh.ohMyZsh = {
    enable = true;
    plugins = [
      "git"
      "python"
      "man"
      "vi-mode"
      "docker"
      "docker-compose"
    ];
    theme = "robbyrussell";
  };
}
