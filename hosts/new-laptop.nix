{ pkgs, config, ... }:
{
  imports = [ ./base.nix ];
  networking.hostName = "nixos-new-laptop"; # Define your hostname.
  services.udev.extraHwdb = ''
    evdev:atkbd:dmi:bvn*:bvr*:bd*:svn*:pn*:pvr*
     KEYBOARD_KEY_56=leftshift
  '';
  # Keyd for key remapping (replaces xmodmap)
  environment.systemPackages = with pkgs; [
    libva-utils
    libva
    s-tui
    stress
    perf # part of linux-tools / linuxPackages.cpupower
    powertop
    fwupd
    lm_sensors
    fwupd-efi

  ];

  services.tlp.enable = true;
  services.tlp.settings = {
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

  };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
      libva
    ];
  };
  services.hardware.bolt.enable = true;
  # services.udev.extraRules = ''
  #   SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-USBC000:001", ATTR{current_max}="2250000"
  # '';

  # Enable fwupd service
  services.fwupd.enable = true;

  # For Thunderbolt dock detection

  # Make sure fwupd command is available
}
