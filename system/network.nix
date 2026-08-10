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
  sing-box = unstable.sing-box.overrideAttrs (oldAttrs: rec {
    version = "1.14.0-alpha.34";
    src = unstable.fetchFromGitHub {
      owner = "SagerNet";
      repo = "sing-box";
      tag = "v${version}";
      hash = "sha256-QwG46iZtc5jqWar/28/K9STZHWnLUwofHBlR2mE5lYs=";
    };
    vendorHash = "sha256-c99as3LIzPR/IZel76rEOJ/kHmxE0fwJV84eSPG98Ls=";
    tags = oldAttrs.tags ++ [ "with_cloudflared" ];
  });
  slipstream = (pkgs.callPackage ./slipstream.nix { });
  paqet = (pkgs.callPackage ./paqet.nix { });
  chproxy = pkgs.callPackage ../utils/chproxy.nix { inherit sing-box; };

  # the per-profile base config chproxy reads at /etc/chproxy/chproxy.json.
  # Carrier outbounds are NOT here — they live in the runtime /etc/proxies.json.
  sb = import ../utils/sing-box.nix;
  baseConfig = sb.mkBaseConfig {
    defaultProxy = secrets.defaultProxy;
    wgFront = secrets.wgFront;
    wgBypass = secrets.wg-bypass;
  };
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
  programs.throne.tunMode.enable = false;
  programs.throne.tunMode.setuid = false;
  programs.throne.package = unstable.throne;

  # chproxy base config (per-profile: base + the single wg front). The carrier
  # outbounds are a separate, runtime-writable file at /etc/proxies.json.
  environment.etc."chproxy/chproxy.json".source =
    pkgs.writeText "chproxy.json" (builtins.toJSON baseConfig);

  # seed /etc/current-proxy with "default" once (writable runtime state — never
  # an environment.etc store symlink). chproxy also treats an absent file as
  # "default", which resolves to chproxy.json's defaults.proxy.
  systemd.tmpfiles.rules = [
    "f /etc/current-proxy 0644 root root - default"
  ];

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
      serviceConfig = {
        Restart = "always";
        # User = "novpn"; # ← runs as novpn, triggers the uid routing rule
        # Group = "novpn";
        IPMark = 520;
        ExecStart = "${chproxy}/bin/chproxy -d";
      };
      path = [
        sing-box
        pkgs.jq
        pkgs.iproute2
      ];
      wantedBy = [ "multi-user.target" ];
    };
  };
}
