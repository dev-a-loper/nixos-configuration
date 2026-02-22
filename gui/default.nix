{
  pkgs,
  config,
  unstable,
  caelestia-shell,
  ...
}:
let
  userName = config.userConfiguration.name;
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
  systemd.user.services.xdg-desktop-portal-gtk.enable = false;

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
    imports = [
      caelestia-shell.homeManagerModules.default
      {
        programs.caelestia = {
          enable = true;
          systemd.enable = true; # starts after your Wayland target
          settings = {
            # Declarative shell.json settings

            bar."persistent" = false;
            services.useFahrenheit = false;
            general.apps.terminal = "alacritty";
            bar.status.showBattery = (
              config.networking.hostName == "nixos-laptop" || config.networking.hostName == "nixos-new-laptop"
            );
            paths.wallpaperDir = "~/Images";
          };
          cli.enable = true; # adds caelestia-cli to PATH
        };
      }
    ];

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
      theme = {
        name = "Materia-dark";
        package = pkgs.materia-theme;
      };
    };
    home.file.".config/hypr/hyprland.conf".text =
      (import ./hyprland-config.nix {
        pkgs = pkgs;
        config = config;
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
    hyprlandPlugins.hyprgrass
    hyprlandPlugins.hyprbars
    hyprlandPlugins.hyprexpo

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
    ];
  };
}
