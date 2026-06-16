{ pkgs, config, ... }:
let
  userName = config.userConfiguration.name;
in
{
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.registry-mirrors = [ "https://registry.docker.ir" ];
  virtualisation.docker.daemon.settings.ipv6 = false;

  virtualisation.docker.daemon.settings.data-root = "/var/lib/d22";
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;
  home-manager.users.${userName} = {
    dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = [ "qemu:///system" ];
        uris = [ "qemu:///system" ];
      };
    };
  };
  environment.systemPackages = [ pkgs.vagrant ];
  users.users.${userName}.extraGroups = [ "libvirtd" ];

}
