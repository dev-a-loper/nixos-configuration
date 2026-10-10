{
  config,
  pkgs,
  unstable,
  ...
}:
let
  secrets = config.userConfiguration.secrets;
  awg-config = pkgs.writeTextFile {
    name = "awg-config";
    text = secrets.awg-config;
    destination = "/awg.conf";
  };
  sing-box = unstable.sing-box;
  slipstream = (pkgs.callPackage ./slipstream.nix { });
  paqet = (pkgs.callPackage ./paqet.nix { });
  chproxy = pkgs.callPackage ../utils/chproxy { inherit sing-box; };

  # chproxy runtime files (see utils/chproxy/chproxy for the full contract):
  # one full sing-box template (mixed + tun + this profile's wg front) plus
  # the settings globals. Carrier outbounds are NOT here — they live in the
  # runtime /etc/proxies.json; extra templates can be dropped into /etc/chproxy
  # by hand (any *.json except state/settings/chproxy).
  sb = import ../utils/sing-box.nix;
  mainTemplate = sb.mkTemplate {
    wgFront = secrets.wgFront;
    wgBypass = secrets.wg-bypass;
  };
  # carrier-direct escape hatch: same inbounds, no wg front — for carriers
  # that can't carry the front's UDP (e.g. socks) or when the front is down.
  plainTemplate = sb.mkTemplate { };
  chproxySettings = sb.mkSettings { defaultProxy = secrets.defaultProxy; };
  mainJson = pkgs.writeText "chproxy-main.json" (builtins.toJSON mainTemplate);
  plainJson = pkgs.writeText "chproxy-plain.json" (builtins.toJSON plainTemplate);
  settingsJson = pkgs.writeText "chproxy-settings.json" (builtins.toJSON chproxySettings);
in
{
  imports = [ ];
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
  # programs.throne.tunMode.enable = false;
  # programs.throne.tunMode.setuid = false;
  # programs.throne.package = unstable.throne;

  # chproxy template + settings (per-profile). The template carries this
  # profile's wg front and both tunnel routing sections (x-chproxy); state
  # (/etc/chproxy/state.json) is writable runtime data — never an
  # environment.etc store symlink. A legacy /etc/current-proxy is migrated by
  # chproxy itself on first run.
  environment.etc."chproxy/main.json".source = mainJson;
  environment.etc."chproxy/plain.json".source = plainJson;
  environment.etc."chproxy/settings.json".source = settingsJson;

  environment.systemPackages = [
    slipstream
    pkgs.dig
    paqet
    pkgs.conntrack-tools
    pkgs.iptstate
    pkgs.nmstate
    pkgs.xray
    pkgs.v2ray
    sing-box
    unstable.tun2socks
    unstable.amnezia-vpn
    unstable.amneziawg-go
    unstable.amneziawg-tools
    unstable.tor
    chproxy
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
    services.chproxy = {
      enable = true;
      description = "chproxy — sing-box switcher";
      after = [ "network.target" ];
      # environment.etc changes alone don't restart units — the daemon composes
      # its config at START, so a rebuilt template must bounce the service.
      restartTriggers = [
        mainJson
        plainJson
        settingsJson
      ];
      serviceConfig = {
        Restart = "always";
        # NOTE: the old IPMark=520 was silently ignored by systemd ("Unknown
        # key"); sing-box's anti-recursion mark now comes from the template's
        # route.default_mark instead (see utils/sing-box.nix).
        ExecStart = "${chproxy}/bin/chproxy daemon";
      };
      path = [
        sing-box
        pkgs.jq
        pkgs.iproute2
        pkgs.openresolv # resolvconf — DNS leak pin while the wg front is up
      ];
      wantedBy = [ "multi-user.target" ];
    };
  };
}
