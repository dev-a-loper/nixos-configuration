{
  config,
  pkgs,
  unstable,
  ...
}:
let
  secrets = config.userConfiguration.secrets;
  proxies = secrets.proxies;
  defaultProxy = secrets.defaultProxy;
  awg-config = pkgs.writeTextFile {
    name = "awg-config";
    text = secrets.awg-config;
    destination = "/awg.conf";
  };
  proxiesDir = pkgs.symlinkJoin {
    name = "proxies";
    paths = pkgs.lib.mapAttrsToList (
      name: value: pkgs.writeShellScriptBin "proxy-${name}" value
    ) proxies;
  };
  slipstream = (pkgs.callPackage ./slipstream.nix { });
  paqet = (pkgs.callPackage ./paqet.nix { });
  chproxy = pkgs.writeShellScriptBin "chproxy" ''
    if [ -z "$1" ]; then
      echo "Usage: chproxy <proxy-name>"
      echo "Available proxies: ${pkgs.lib.concatStringsSep " " (pkgs.lib.attrNames proxies)}"
      exit 1
    fi
    if [ ! -e "${proxiesDir}/bin/proxy-$1" ]; then
      echo "Error: Proxy '$1' not found"
      echo "Available proxies: ${pkgs.lib.concatStringsSep " " (pkgs.lib.attrNames proxies)}"
      exit 1
    fi
    echo "$1" > /etc/current-proxy;
    sudo systemctl restart proxy.service;
  '';
in
{
  imports = [ ];
  networking.nameservers = [ "1.1.1.1" ];
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [
    1080
    5900
    8443
  ];
  networking.firewall.allowedUDPPorts = [
    5900
    8443
    8080
  ];

  networking.nftables.enable = true;
  networking.firewall.backend = "nftables";
  services.vnstat.enable = true;
  services.expressvpn.enable = true;
  services.openvpn.servers = {
    openvpn = {
      autoStart = false;
      config = config.userConfiguration.secrets.openvpn;
      updateResolvConf = true;
    };
  };

  # programs.amnezia-vpn.enable = true;
  programs.proxychains = {
    enable = true;
    proxies = {
      torproxy.enable = false;
      main = {
        type = "socks5";
        enable = true;
        host = "127.0.0.1";
        port = 1080;
      };
    };

  };

  environment.shellAliases.sp = "export https_proxy=http://localhost:1080;";
  environment.shellAliases.ssp = "sudo https_proxy=http://localhost:1080 -s";
  services.tor = {
    enable = true;
    client.enable = true;
    torsocks.enable = true;
  };
  programs.throne.enable = true;
  programs.throne.tunMode.enable = true;

  environment.systemPackages = [
    slipstream
    paqet
    pkgs.xray
    pkgs.v2ray
    unstable.v2rayn
    unstable.tor-browser
    unstable.sing-box
    unstable.v2raya
    unstable.tun2socks
    unstable.amnezia-vpn
    unstable.amneziawg-go
    unstable.amneziawg-tools
    unstable.tor
    pkgs.expressvpn
    chproxy
    unstable.wireguard-tools
    pkgs.udp2raw
    pkgs.innernet
  ];
  services.snowflake-proxy.enable = true;
  services.dbus.packages = [ unstable.amnezia-vpn ];
  users.users.novpn = {
    isSystemUser = true;
    group = "novpn";
  };
  users.groups.novpn = { };

  systemd = {
    packages = [ unstable.amnezia-vpn ];

    services.amnezia = {
      enable = true;
      description = "amnezia vpn service (awg-quick)";
      after = [ "network.target" ];

      serviceConfig =
        let
          awg-quick = "${pkgs.amneziawg-tools}/bin/awg-quick";
        in
        {
          User = "root"; # Already correct - root has necessary permissions
          Type = "oneshot";
          RemainAfterExit = true;

          # Add necessary capabilities
          AmbientCapabilities = [
            "CAP_NET_ADMIN"
            "CAP_NET_BIND_SERVICE"
            "CAP_NET_RAW"
          ];
          CapabilityBoundingSet = [
            "CAP_NET_ADMIN"
            "CAP_NET_BIND_SERVICE"
            "CAP_NET_RAW"
          ];

          # Allow network configuration
          PrivateNetwork = false;

          # Ensure it can modify system network settings
          RestrictAddressFamilies = [
            "AF_NETLINK"
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];

          # Allow the service to interact with systemd-resolved if needed
          SystemCallFilter = [
            "@network-io"
            "@system-service"
          ];

          # Original commands
          ExecStart = [ "${awg-quick} up ${awg-config}/awg.conf" ];
          ExecStop = [ "${awg-quick} down ${awg-config}/awg.conf" ];
        };

      # Expand path to include all needed tools
      path = [
        unstable.amneziawg-tools
        pkgs.iproute2 # For ip command
        pkgs.openresolv # For resolvconf
        pkgs.coreutils # For basic commands
      ];
    };
    services.proxy = {
      enable = true;
      description = "main proxy for system";
      after = [ "network.target" ];
      serviceConfig = {
        Restart = "always";
        # User = "novpn"; # ← runs as novpn, triggers the uid routing rule
        # Group = "novpn";
        ExecStart = pkgs.writeShellScript "proxy-start" ''
          if [ -f /etc/current-proxy ]; then
            name=$(cat /etc/current-proxy)
          else
            name="${defaultProxy}"
          fi
          exec "${proxiesDir}/bin/proxy-$name"
        '';
      };
      path = [
        slipstream
        unstable.xray
        unstable.sing-box
        unstable.v2raya
        paqet
        pkgs.udp2raw
      ];
      wantedBy = [ "multi-user.target" ];
    };
  };
}
