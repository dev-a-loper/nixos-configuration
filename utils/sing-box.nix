# Pure structural data + the chproxy.json renderer. NO pkgs. NO secrets.
#
# The carrier outbounds no longer live in Nix at all — they're a runtime file at
# /etc/proxies.json that you edit directly (add a carrier, `chproxy <name>`, no
# rebuild). This module only renders the per-profile base config that chproxy
# reads at /etc/chproxy/chproxy.json: the secret-free structural defaults
# (public DNS resolvers, RFC1918 ranges, routing-table ids) plus the single
# wireguard front endpoint for this profile.
#
#   sb = import ./utils/sing-box.nix;        # no pkgs arg
#   builtins.toJSON (sb.mkBaseConfig {
#     defaultProxy = "pro";
#     wgFront      = s.warpEndpoint;          # raw JSON string blob
#     wgBypass     = s.wg-bypass;             # extra CIDRs kept on the main table
#   })
let
  read = x: if builtins.isString x then builtins.fromJSON x else x;

  # classic SOCKS5+HTTP mixed listener on :1080
  mixed-inbound = {
    type = "mixed";
    tag = "mixed-in";
    listen = "0.0.0.0";
    listen_port = 1080;
  };

  # a system-wg tunnel listens on :3080 (kept apart from :1080 so it never
  # clashes with another already-running proxy)
  system-wg-mixed-in = {
    type = "mixed";
    tag = "mixed-in";
    listen = "0.0.0.0";
    listen_port = 3080;
  };

  # transparent TUN inbound, used when -t is passed
  tun-inbound = {
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

  # remote resolver template — chproxy adds `detour` (the final tag) and
  # `type` (tls normally, udp under a system-wg front) at compose time.
  dns-remote-template = {
    server = "8.8.8.8";
    domain_resolver = "dns-local";
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

  # sniff the first hop, then steal DNS for the resolver. chproxy injects the
  # constant inbound list ["mixed-in","tun-in"] at compose time.
  sniff-rule = {
    action = "sniff";
  };
  hijack-dns-rule = {
    action = "hijack-dns";
    protocol = "dns";
  };

  # keep LAN/Docker traffic direct — auto-added whenever -t is passed
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

  # RFC1918 + loopback — always kept off a system-wg tunnel so LAN, Docker
  # bridge networks and localhost still reach the host directly.
  private-bypass = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "127.0.0.0/8"
  ];

  # structural overlay turning any raw wg endpoint into a carrier-riding system
  # tunnel. Idempotent on blobs that already carry these fields (e.g. the
  # systemWgEndpoint blob already has system/name/detour, just gains an explicit
  # tag).
  system-wg-struct = {
    system = true;
    name = "www";
    detour = "proxy";
    tag = "wire";
  };
in
{
  # Build the chproxy.json attrset for this profile. `wgFront` is the raw
  # wireguard endpoint blob (JSON string or attrset); `wgBypass` the extra CIDRs
  # every system-wg tunnel must keep on the main table (caller-supplied, since
  # it carries server IPs). chproxy itself adds the carrier's own IP + RFC1918
  # on top at runtime.
  mkBaseConfig =
    {
      defaultProxy,
      wgFront,
      wgBypass,
      service ? "chproxy",
      stateFile ? "/etc/current-proxy",
      singboxBin ? "sing-box",
      table ? 123,
      fwmark ? 520,
      interface ? "www",
    }:
    {
      inherit service;
      state_file = stateFile;
      singbox_bin = singboxBin;
      defaults = {
        proxy = defaultProxy;
      };
      wg_front = (read wgFront) // system-wg-struct;

      mixed_inbound = mixed-inbound;
      system_wg_mixed_inbound = system-wg-mixed-in;
      tun_inbound = tun-inbound;

      dns = {
        remote_template = dns-remote-template;
        direct = dns-direct;
        local = dns-local;
        localhost_rules = localhost-dns-rules;
      };

      inherit experimental;
      sniff_rule = sniff-rule;
      hijack_dns_rule = hijack-dns-rule;
      direct_private_rule = direct-private-rule;
      private_bypass = private-bypass;

      wg = {
        inherit table fwmark interface;
        wg_bypass = wgBypass;
      };
    };
}
