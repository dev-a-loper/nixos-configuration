{ pkgs, config, ... }:
{
  imports = [
    ./base.nix
    ./hidpi.nix
  ];
  networking.hostName = "nixos-home-desktop"; # Define your hostname.

  environment.systemPackages = [

  ];
  systemd.services.task-sync = {
    enable = true;
    description = "taskwarrior sync server";
    after = [ "network.target" ];
    serviceConfig = {
      Restart = "always";
      ExecStart = "${pkgs.taskchampion-sync-server}/bin/taskchampion-sync-server --listen 0.0.0.0:8443";
    };
    wantedBy = [ "multi-user.target" ];
  };

  nixpkgs.config.permittedInsecurePackages = [ "dcraw-9.28.0" ];
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    # powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    # powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    open = true;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  boot.loader.grub.gfxmodeEfi = "1024x768";
  nix.settings.substituters = [ "https://nix-community.cachix.org" ];
  nix.settings.trusted-public-keys = [
    # Compare to the key published at https://nix-community.org/cache
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
  # nixpkgs.config.cudaSupport = true;

}
