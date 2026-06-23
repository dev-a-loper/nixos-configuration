# Pure sing-box helpers — NO secrets live in this file.
#
# Private keys, uuids, passwords and proxy server addresses are passed in by
# the caller (the secrets module). Only non-secret structural defaults are
# baked in here (public DNS resolvers, RFC1918 ranges, routing-table ids) and
# every one of them is overridable.
#
#   singbox = import ./utils/sing-box.nix { inherit pkgs; };
#
#   # a normal proxy:
#   singbox.mkSingbox (singbox.create-config {
#     outbound = ''{"type":"vless","tag":"proxy",…}'';   # JSON string
#   })
#
#   # a policy-routed system wireguard tunnel (the `www` interface): the config
#   # is just create-config again; mkSystemWg only adds the ip-rule dance.
#   singbox.mkSystemWg {
#     config-json = singbox.create-config { outbound = …; wireguard = …; final = "wire"; };
#     bypass = [ "10.9.0.0/24" ];   # extra CIDRs to keep on the main table
#   }
{ pkgs }:
let
  # accept either a JSON string or an already-parsed Nix value
  read = x: if builtins.isString x then builtins.fromJSON x else x;

  # classic SOCKS5+HTTP mixed listener on :1080
  default-mixed-in = {
    type = "mixed";
    tag = "mixed-in";
    listen = "0.0.0.0";
    listen_port = 1080;
  };

  # transparent TUN inbound, used when tun = true
  default-tun-in = {
    type = "tun";
    tag = "tun-in";
    address = [ "198.18.0.1/16" ];
    auto_redirect = true;
    auto_route = true;
    interface_name = "throne-tun";
    mtu = 1500;
    route_exclude_address = [
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "127.0.0.0/8"
    ];
    stack = "mixed";
    strict_route = false;
  };

  direct-outbound = {
    type = "direct";
    tag = "direct";
  };

  # keep localhost out of the remote resolver
  localhost-dns-rules = [
    {
      action = "predefined";
      domain = "localhost";
      query_type = "A";
      rcode = "NOERROR";
      answer = "localhost. IN A 127.0.0.1";
    }
    {
      action = "predefined";
      domain = "localhost";
      query_type = "AAAA";
      rcode = "NOERROR";
      answer = "localhost. IN AAAA ::1";
    }
  ];

  # remote resolver rides the tunnel (`detour` = the proxy tag); `type` lets a
  # system-wireguard tunnel use plain UDP DNS instead of DoT.
  mk-dns-remote = detour: type: {
    inherit detour type;
    domain_resolver = "dns-local";
    server = "8.8.8.8";
    tag = "dns-remote";
  };
  dns-direct = {
    domain_resolver = "dns-local";
    server = "223.5.5.5";
    tag = "dns-direct";
    type = "udp";
  };
  dns-local = {
    tag = "dns-local";
    type = "local";
  };
  mk-dns-servers =
    {
      direct-dns ? true,
      dns-detour,
      dns-remote-type ? "tls",
    }:
    [ (mk-dns-remote dns-detour dns-remote-type) ]
    ++ (if direct-dns then [ dns-direct ] else [ ])
    ++ [ dns-local ];

  experimental = {
    cache_file = {
      enabled = true;
      store_fakeip = true;
      store_rdrc = true;
    };
    clash_api = {
      default_mode = "";
    };
  };

  # sniff the first hop, then steal DNS for the resolver
  sniff-rule = {
    action = "sniff";
    inbound = [
      "mixed-in"
      "tun-in"
    ];
  };
  hijack-dns-rule = {
    action = "hijack-dns";
    protocol = "dns";
  };

  # keep LAN/Docker traffic direct — auto-added whenever tun = true
  direct-private-rule = {
    action = "route";
    ip_cidr = [
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
      "127.0.0.0/8"
    ];
    outbound = "direct";
  };

  # RFC1918 + loopback — always kept off a system-wireguard tunnel so LAN,
  # Docker bridge networks and localhost still reach the host directly.
  private-bypass = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "127.0.0.0/8"
  ];

  # ── create-config: build a full sing-box config around one outbound ──
  #
  #   outbound       primary outbound (JSON string/attrset); null when the
  #                  tunnel is a wireguard endpoint instead.
  #   wireguard      a wireguard *endpoint* (sing-box 1.11+ endpoints[]);
  #                  its tag becomes route.final unless `final` is set.
  #   final          route.final; defaults to the tunnel tag → "direct".
  #   inbounds       listener list; defaults to a single mixed:1080.
  #   tun            append the TUN inbound (and keep private ranges direct).
  #   extra-inbounds extra inbounds appended after tun.
  #   extra-rules    route.rules appended after sniff/hijack.
  #   route-extra    shallow-merged into route (e.g. default_mark).
  #   direct-dns     include the 223.5.5.5 resolver; when false, domains
  #                  resolve via dns-local instead.
  #   dns-remote-type  dns-remote transport; "tls" (DoT) normally, "udp" when
  #                  the tunnel itself already encrypts (system wireguard).
  create-config =
    {
      outbound ? null,
      wireguard ? null,
      final ? null,
      inbounds ? [ default-mixed-in ],
      tun ? false,
      extra-inbounds ? [ ],
      extra-rules ? [ ],
      route-extra ? { },
      sniff-inbounds ? [
        "mixed-in"
        "tun-in"
      ],
      direct-dns ? true,
      default-domain-resolver ? null,
      dns-remote-type ? "tls",
      find-process ? true,
    }:
    let
      ob = read outbound;
      wg = read wireguard;

      # the tunnel tag: wireguard endpoint, else the outbound, else direct
      proxy-tag =
        if wireguard != null then
          wg.tag or "wire"
        else if outbound != null then
          ob.tag or "proxy"
        else
          "direct";
      final-tag = if final != null then final else proxy-tag;

      resolver =
        if default-domain-resolver != null then
          default-domain-resolver
        else if direct-dns then
          "dns-direct"
        else
          "dns-local";

      endpoints = if wireguard == null then [ ] else [ wg ];
      outbounds = (if outbound == null then [ ] else [ ob ]) ++ [ direct-outbound ];
      all-inbounds = inbounds ++ (if tun then [ default-tun-in ] else [ ]) ++ extra-inbounds;
      all-rules = [
        (sniff-rule // { inbound = sniff-inbounds; })
      ]
      ++ (if tun then [ direct-private-rule ] else [ ])
      ++ [ hijack-dns-rule ]
      ++ extra-rules;
    in
    builtins.toJSON {
      certificate.store = "system";
      dns = {
        rules = localhost-dns-rules;
        servers = mk-dns-servers {
          inherit direct-dns dns-remote-type;
          dns-detour = final-tag;
        };
      };
      inherit endpoints experimental outbounds;
      inbounds = all-inbounds;
      log.level = "info";
      route = (
        {
          default_domain_resolver = {
            server = resolver;
            strategy = "";
          };
          final = final-tag;
          find_process = find-process; # sing-box field is snake_case
          rule_set = [ ];
          rules = all-rules;
        }
        // route-extra
      );
    };

  # extract outbounds[0] from a full config JSON string, returned again as a
  # JSON string — reuse one proxy's outbound elsewhere.
  getOutbound = config: builtins.toJSON (builtins.elemAt (read config).outbounds 0);

  # turn a config JSON string into a runnable `sing-box run` script
  mkSingbox = json: ''
    #!/bin/sh
    export ENABLE_DEPRECATED_WIREGUARD_OUTBOUND=true
    sing-box run -c ${builtins.toFile "sing-box-config.json" json}
  '';
  mkXray = json: ''
    #!/bin/sh
    xray run -c ${builtins.toFile "xray-config.json" json} -format=json
  '';

  # ── mkSystemWg: run a sing-box config as a policy-routed wireguard tunnel ──
  #
  # The config (built with create-config + a wireguard endpoint whose
  # `system = true` and `name` sets the interface) is started in the
  # background; once sing-box brings the interface up we install:
  #   - default route via the interface into `table`
  #   - ip rules keeping `bypass` CIDRs (plus the proxy server, RFC1918 and
  #     loopback) on the main table, so they don't recurse into the tunnel
  #   - a fwmark rule + the table lookup
  # All of that is torn down on exit.
  mkSystemWg =
    {
      config-json,
      bypass ? [ ],
      table ? 123,
      fwmark ? 520,
    }:
    let
      cfg = builtins.fromJSON config-json;
      endpoint =
        if (cfg.endpoints or [ ]) == [ ] then { name = "www"; } else builtins.elemAt cfg.endpoints 0;
      interface = endpoint.name or "www";

      # the proxy server the tunnel rides on must stay on the main table,
      # otherwise its own traffic would loop back into the tunnel.
      proxy-ip = (read (getOutbound config-json)).server;
      cidrs = [ "${proxy-ip}/32" ] ++ bypass ++ private-bypass;

      rule-add = cidr: "ip rule add to ${cidr} lookup main priority 900";
      rule-del = cidr: "ip rule del to ${cidr} lookup main priority 900 2>/dev/null || true";
      addBypass = builtins.concatStringsSep "\n" (map rule-add cidrs);
      delBypass = builtins.concatStringsSep "\n" (map rule-del cidrs);
    in
    ''
      #!/bin/sh
      export PATH=${pkgs.iproute2}/bin:$PATH

      # sing-box creates the ${interface} WireGuard interface (system = true)
      # at startup, so it must already be running before we install routes
      # that reference `dev ${interface}`.
      sing-box run -c ${builtins.toFile "sing-box-config.json" config-json} &
      SB_PID=$!

      i=0
      while ! ip link show ${interface} >/dev/null 2>&1; do
        kill -0 "$SB_PID" 2>/dev/null || { echo "mkSystemWg: sing-box exited before ${interface} came up" >&2; exit 1; }
        i=$((i + 1))
        [ "$i" -gt 150 ] && { echo "mkSystemWg: timed out waiting for ${interface}" >&2; kill "$SB_PID"; exit 1; }
        sleep 0.2
      done

      ip route replace default dev ${interface} table ${toString table}
      ${addBypass}
      ip rule add fwmark ${toString fwmark} lookup main priority 900
      ip rule add lookup ${toString table} priority 2000

      cleanup() {
        trap - EXIT INT TERM
        ip route del default dev ${interface} table ${toString table} 2>/dev/null || true
        ${delBypass}
        ip rule del fwmark ${toString fwmark} lookup main priority 900 2>/dev/null || true
        ip rule del lookup ${toString table} priority 2000 2>/dev/null || true
        kill "$SB_PID" 2>/dev/null || true
      }
      trap cleanup EXIT INT TERM

      wait "$SB_PID"
    '';
in
{
  inherit
    create-config
    getOutbound
    mkSingbox
    mkXray
    mkSystemWg
    ;
  inherit
    default-mixed-in
    default-tun-in
    direct-private-rule
    ;
}
