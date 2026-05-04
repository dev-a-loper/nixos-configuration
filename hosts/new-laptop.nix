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
  
}
