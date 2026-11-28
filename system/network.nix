{
  config,
  pkgs,
  unstable,
  chproxy,
  ...
}:
let
  secrets = config.userConfiguration.secrets;
  awg-config = pkgs.writeTextFile {
    name = "awg-config";
    text = secrets.awg-config;
    destination = "/awg.conf";
  };
  slipstream = (pkgs.callPackage ./slipstream.nix { });
  paqet = (pkgs.callPackage ./paqet.nix { });
in
{
  imports = [ chproxy.nixosModules.default ];
  # Soft DNS posture for the boot parent/default profile: NM keeps feeding
  # DHCP/ISP resolvers into resolvconf as usual. The hard no-leak posture
  # (NM dns=none + static 1.1.1.1/1.0.0.1 base) is james-only — see
  # vars/secrets.james.nix.
  networking.nameservers = [ "1.1.1.1" ];
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [
    3080
    1080
    5900
    8443
    8080
  ];
  networking.firewall.allowedUDPPorts = [
    3080
    8080
    5900
    8443
    8080
  ];

  networking.nftables.enable = true;
  networking.firewall.backend = "nftables";
  services.vnstat.enable = true;
  services.tailscale.enable = true;
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
  programs.throne.tunMode.setuid = true;
  # programs.throne.package = unstable.throne;

  # chproxy — its own flake (./chproxy, a `path:` input: edits there need no
  # re-lock) carrying the package, sing-box-extended and the services.chproxy
  # module (unit, /etc/chproxy, CLI on PATH, the tailscale escape — on here
  # because services.tailscale is).
  #
  # The templates are FULLY CUSTOM per profile — plain data authored in the
  # profile's vars/secrets.<name>.nix as secrets.chproxyTemplates (name →
  # complete sing-box config + the reserved x-chproxy section) and rendered
  # by the module 1:1, untouched. There is deliberately no shared template
  # engine: profiles differ by editing their own template, not by threading
  # options through one. Carrier outbounds are NOT declared — they live in
  # the runtime /etc/proxies.json; extra templates can be dropped into
  # /etc/chproxy by hand (any *.json except state/settings/chproxy).
  services.chproxy = {
    enable = true;
    # No IPv6 egress, ever: chproxy's tunnels policy-route IPv4 only, so any
    # v6 path would bypass them (IP leak). The ISP is v4-only today — this
    # keeps it moot even if that ever changes. Tailscale falls back to v4 fine.
    ipv4Only = true;
    templates = secrets.chproxyTemplates;
    settings.defaults.proxy = secrets.defaultProxy;
  };

  environment.systemPackages = [
    slipstream
    pkgs.dig
    paqet
    pkgs.conntrack-tools
    pkgs.iptstate
    pkgs.nmstate
    unstable.xray
    pkgs.v2ray
    unstable.tun2socks
    unstable.amnezia-vpn
    unstable.amneziawg-go
    unstable.amneziawg-tools
    unstable.tor
    pkgs.jq
    pkgs.iproute2
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
  };
}
