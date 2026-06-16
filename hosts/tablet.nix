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
  nix.gc.options = lib.mkForce "--delete-older-than 7d";
  boot.loader.grub.useOSProber = lib.mkForce false;
  services.xserver.desktopManager.xfce.enable = lib.mkForce false;
  services.xserver.displayManager.lightdm.enable = lib.mkForce false;
  services = {
    desktopManager.plasma6.enable = true;

    displayManager.sddm.enable = true;

    displayManager.sddm.wayland.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # KDE
    kdePackages.discover # Optional: Install if you use Flatpak or fwupd firmware update sevice
    kdePackages.kcalc # Calculator
    kdePackages.kcharselect # Tool to select and copy special characters from all installed fonts
    kdePackages.kclock # Clock app
    kdePackages.kcolorchooser # A small utility to select a color
    kdePackages.kolourpaint # Easy-to-use paint program
    kdePackages.ksystemlog # KDE SystemLog Application
    kdePackages.sddm-kcm # Configuration module for SDDM
    kdiff3 # Compares and merges 2 or 3 files or directories
    kdePackages.isoimagewriter # Optional: Program to write hybrid ISO files onto USB disks
    kdePackages.partitionmanager # Optional: Manage the disk devices, partitions and file systems on your computer
    # Non-KDE graphical packages
    hardinfo2 # System information and benchmarks for Linux systems
    vlc # Cross-platform media player and streaming server
    wayland-utils # Wayland utilities
    wl-clipboard # Command-line copy/paste utilities for Wayland
  ];
  networking.hostName = "nixos-tablet"; # Define your hostname.
}
// import ./tablet-disko.nix
