{
  pkgs,
  config,
  unstable,
  HyprQuickFrame,
  ...
}:
let
  userName = config.userConfiguration.name;
  patchedPkgs =
    import
      (builtins.fetchTree {
        type = "github";
        owner = "JonnieCache";
        repo = "nixpkgs";
        rev = "231ea250eee538df1b939ca7899e0e80e7bcb08c";
      })
      {
        inherit (unstable) system;
        config.allowUnfree = true;
      };

  fixedHyprgrass = patchedPkgs.hyprlandPlugins.hyprgrass.overrideAttrs (old: {
    version = "0.8.2-unstable-2025-04-14";
    src = unstable.fetchFromGitHub {
      owner = "horriblename";
      repo = "hyprgrass";
      rev = "cd4810130e2e8fd8a0f7be4b69b42b9c902ad00a";
      hash = "sha256-PJ9w8WTTxI/lJVgCFsNRYodG4Ab3H4EOgjSq1dHli+A=";
    };
  });

in
{
  imports = [
    ./waybar.nix
    ./rofi.nix
    ./firefox.nix
    ./media.nix
  ];

  xdg.portal = {
    enable = true;

    config = {
      preferred = {
        default = "wlroots";
      };
    };
    wlr.enable = true;
    # Add the WLR backend for Hyprland/Wayland
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk # Recommended for GTK file dialogs
    ];

    # Tells GTK apps to use the portal instead of native dialogs
  };

  # Mask xdg-desktop-portal-gtk.service to prevent it from interfering with wlr portal
  # systemd.user.services.xdg-desktop-portal-gtk.enable = false;

  fonts.packages = with pkgs; [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.fira-code
    vazir-code-font
  ];
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkbOptions in tty.
  };

  # Enable Hyprland (Wayland)
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Display manager
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    enableHidpi = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  services.libinput.touchpad.disableWhileTyping = true;

  home-manager.users.${userName} = {

    services.flameshot.enable = true;
    services.flameshot.settings = {
      General = {
        useGrimAdapter = true;
      };
    };
    home.pointerCursor = {
      package = pkgs.vanilla-dmz;
      name = "Vanilla-DMZ";
      size = 72;
    };
    gtk = {
      enable = true;

      gtk4.theme = null;
      theme = {
        name = "Materia-dark";
        package = pkgs.materia-theme;
      };
    };
    home.file.".config/hyprquickframe/theme.toml".text = ''
      # Main highlight color on the active tab
      accent = "#cba6f7"
      # Text color on the active tab (should contrast with accent)
      accentText = "#11111b"
      # Dim overlay opacity when selecting (0.0 - 1.0)
      dimOpacity = 0.6
      # Corner radius on selection outline
      borderRadius = 10
      # Selection outline thickness
      outlineThickness = 2
      # Distance from bottom edge to the bar
      bottomMargin = 60
      # Global animation toggle (true/false)
      animations = false
      # Tool to use for the "edit" screenshot action (e.g., "satty" or "gradia")
      annotationTool = "satty"

      [bar]
      # Segmented control background
      background = "rgba(38, 38, 38, 0.4)"
      # Segmented control border
      border = "rgba(255, 255, 255, 0.15)"
      # Inactive tab text color
      text = "#AAFFFFFF"
      # Drop shadow under the bar
      shadow = "#80000000"

      [toggle]
      # Drop shadow under toggle pills
      shadow = "#80000000"
      # Edit toggle icon color
      edit = "#1ABC9C"
      # Temp toggle icon color
      temp = "#2C66D8"

      [share]
      # Icon color when device is reachable
      connected = "#3498DB"
      # Icon color while checking connectivity
      pending = "#95A5A6"
      # Icon color on connection failure
      errorIcon = "white"
      # Background color on connection failure
      errorBackground = "#E74C3C"

      [hooks]
      # Command to run after a screenshot is saved (leave empty to disable)
      # Placeholders: %f = full path, %n = filename, %d = directory, %t = timestamp
      postSaveHook = ""
    '';
    home.file.".config/hypr/hyprland.conf".text =
      (import ./hyprland-config.nix {
        pkgs = pkgs;
        config = config;
        hyprgrass = fixedHyprgrass;
      }).text;
    home.file.".config/hypr/hyprpaper.conf".text = ''
      preload = ~/.background-image
      wallpaper = eDP-1,~/.background-image
      wallpaper = HDMI-A-1,~/.background-image
    '';
    home.file.aiderConfig = {
      target = ".config/aichat/config.yaml";
      text = ''
        vim: true
        model: openrouter:deepseek/deepseek-r1:free
        clients:
          - type: openai-compatible
            name: openrouter
            api_base: https://openrouter.ai/api/v1
            api_key: null
            extra:
              proxy: socks5://127.0.0.1:1080
      '';
    };
    services.dunst.enable = true;
    programs = {
      wofi = {
        enable = true;
      };
      alacritty = {
        enable = true;
      };
    };

  };
  # services.gammastep.enable = true;
  environment.systemPackages = with pkgs; [
    alacritty
    # Window manager and utils
    wofi
    libnotify
    dunst
    translate-shell
    wl-clipboard
    grim
    swappy
    i3status
    scrcpy
    libreoffice

    xarchiver
    unstable.telegram-desktop
    # Hyprland packages
    hyprland
    fixedHyprgrass
    unstable.hyprlandPlugins.hyprbars

    hyprpaper
    # Common Wayland packages
    waybar
    libinput
    lisgd
    rofi
    fcitx5
    arc-icon-theme
    xdg-desktop-portal
    xdg-desktop-portal-wlr
    wvkbd
    pavucontrol
    gimp
    moonlight-qt
    wayvnc

  ];
  programs.thunar.enable = true;
  services.xserver.desktopManager.runXdgAutostartIfNone = true;
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      HyprQuickFrame
    ];
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      capture = "wlr";
    };
  };
}
