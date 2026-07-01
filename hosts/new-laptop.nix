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
    # intel_pstate/HWP mostly ignores cpufreq governors; EPP + platform profile
    # are the real levers. "powersave" is the standard HWP default.
    CPU_SCALING_GOVERNOR_ON_AC = "powersave";
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

    CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance"; # cooler than "performance", same burst
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

    CPU_BOOST_ON_AC = 1; # turbo allowed
    CPU_BOOST_ON_BAT = 0; # cap turbo -> big thermal/battery win on Raptor Lake-U

    RUNTIME_PM_ON_AC = "on"; # devices awake (latency) when plugged in
    RUNTIME_PM_ON_BAT = "auto"; # let idle PCIe sleep on battery

    # Drives the Dell firmware fans + power limits directly (BIOS thermal = Optimized).
    # Dell exposes: cool quiet balanced performance (no low-power/balanced-performance).
    PLATFORM_PROFILE_ON_AC = "performance"; # cooler AC option: "balanced" or "cool"
    PLATFORM_PROFILE_ON_BAT = "cool";
  };

  # Active thermal guard; plays fine with TLP on a Dell.
  services.thermald.enable = true;
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
      libva
    ];
  };
  services.hardware.bolt.enable = true;

  # Enable fwupd service
  services.fwupd.enable = true;
  boot.kernelModules = [ "kvm-intel" ]; # Use "kvm-amd" if you are using an AMD processor

  # For Thunderbolt dock detection

  # Make sure fwupd command is available
}
