{
  config,
  lib,
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
  sing-box = pkgs.sing-box.overrideAttrs (
    finalAttrs: prevAttrs: {
      pname = "sing-box-extended";
      version = "1.14.1-extended-2.7.2";

      src = pkgs.fetchFromGitHub {
        owner = "shtorm-7";
        repo = "sing-box-extended";
        tag = "v${finalAttrs.version}";
        hash = "sha256-bDE90wcoTLBm3lDICO+z7Kl+hhIXBYZN5lsrLXQbL10=";
      };

      vendorHash = "sha256-fR6ZlkSBiM0EiGwd6mWQ07p+gMnYuhugai4x4SsUNiU=";

      # keep everything nixpkgs builds sing-box with, add the extended gates
      tags = prevAttrs.tags ++ [
        "with_masque"
        "with_mtproxy"
        "with_trusttunnel"
        "with_call"
        "with_sudoku"
      ];

      meta = prevAttrs.meta // {
        description = "Universal proxy platform (extended fork)";
        homepage = "https://github.com/shtorm-7/sing-box-extended";
        maintainers = [ ];
      };
    }
  );
  slipstream = (pkgs.callPackage ./slipstream.nix { });
  paqet = (pkgs.callPackage ./paqet.nix { });
  chproxy = pkgs.callPackage ../utils/chproxy { inherit sing-box; };

  # chproxy runtime files (see utils/chproxy/chproxy for the full contract).
  # The templates are FULLY CUSTOM per profile — plain data authored in the
  # profile's vars/secrets.<name>.nix as secrets.chproxyTemplates (name →
  # complete sing-box config + the reserved x-chproxy section) and rendered
  # here 1:1, untouched. There is deliberately no shared template engine:
  # profiles differ by editing their own template, not by threading options
  # through one. Carrier outbounds are NOT here — they live in the runtime
  # /etc/proxies.json; extra templates can be dropped into /etc/chproxy by
  # hand (any *.json except state/settings/chproxy).
  templateFiles = lib.mapAttrs (
    name: cfg: pkgs.writeText "chproxy-${name}.json" (builtins.toJSON cfg)
  ) secrets.chproxyTemplates;
  settingsJson = pkgs.writeText "chproxy-settings.json" (
    builtins.toJSON {
      service = "chproxy";
      singbox_bin = "sing-box";
      proxies_file = "/etc/proxies.json";
      state_file = "/etc/chproxy/state.json";
      defaults = {
        template = "main";
        proxy = secrets.defaultProxy;
      };
    }
  );
in
{
  imports = [ ];
  # Soft DNS posture for the boot parent/default profile: NM keeps feeding
  # DHCP/ISP resolvers into resolvconf as usual. The hard no-leak posture
  # (NM dns=none + static 1.1.1.1/1.0.0.1 base) is james-only — see
  # vars/secrets.james.nix.
  networking.nameservers = [ "1.1.1.1" ];
  # No IPv6 egress, ever: chproxy's tunnels policy-route IPv4 only, so any v6
  # path would bypass them (IP leak). The ISP is v4-only today — this keeps
  # it moot even if that ever changes. sysctls are the hard guarantee (all +
  # default covers future interfaces); enableIPv6=false is the declarative
  # flag. Tailscale falls back to v4 fine.
  networking.enableIPv6 = false;
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };
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

  # chproxy templates + settings (per-profile data, rendered verbatim). State
  # (/etc/chproxy/state.json) is writable runtime data — never an
  # environment.etc store symlink. A legacy /etc/current-proxy is migrated by
  # chproxy itself on first run.
  environment.etc =
    (lib.mapAttrs' (
      name: file: lib.nameValuePair "chproxy/${name}.json" { source = file; }
    ) templateFiles)
    // {
      "chproxy/settings.json".source = settingsJson;
    };

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
      restartTriggers = (lib.attrValues templateFiles) ++ [ settingsJson ];
      serviceConfig = {
        Restart = "always";
        # NOTE: the old IPMark=520 was silently ignored by systemd ("Unknown
        # key"); sing-box's anti-recursion mark comes from the template's
        # route.default_mark instead (authored in vars/secrets.*.nix).
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
