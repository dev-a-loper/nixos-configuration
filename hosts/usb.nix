{
  pkgs,
  lib,
  modulesPath,
  disko,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/all-hardware.nix"
    "${modulesPath}/profiles/base.nix"
    ../default.nix
    disko.nixosModules.disko
  ];

  specialisation.hidpi.configuration = import ./hidpi.nix { inherit pkgs; };
  nix.gc.options = lib.mkForce "--delete-older-than 7d";
  boot.loader.grub.useOSProber = lib.mkForce false;
  services.xserver.desktopManager.xfce.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub.efiInstallAsRemovable = true;
  networking.hostName = "nixos-usb"; # Define your hostname.
  environment.systemPackages = [ pkgs.xfce.thunar ];
  services.logrotate.enable = true;
  boot.tmp.useTmpfs = true;

  boot.kernel.sysctl = {
    # "vm.dirty_ratio" = 10;
    # "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 50;
  };

}
// import ./usb-disko.nix
