# Pure structural data + the chproxy template/settings renderers. NO pkgs. NO secrets.
#
# chproxy's runtime layout (the script at utils/chproxy/chproxy is the contract):
#   /etc/chproxy/<name>.json   templates — COMPLETE sing-box configs plus a
#                              reserved top-level "x-chproxy" key carrying that
#                              template's own routing metadata:
#                                x-chproxy.<tun|wg> = { interface, table, fwmark,
#                                                       dns[], bypass[] }
#                              chproxy strips the key before sing-box sees the
#                              config and uses it to drive `chproxy tun/wg on`.
#                              Reserved template names: state, settings, chproxy.
#   /etc/chproxy/settings.json globals (service, singbox_bin, proxies_file,
#                              defaults) — rendered by mkSettings.
#   /etc/proxies.json          carrier outbounds (runtime, user-maintained, no
#                              rebuild). The selected carrier replaces whatever
#                              the template tags "proxy"; a wireguard-type
#                              carrier is injected into endpoints instead.
#
#   sb = import ./utils/sing-box.nix;        # no pkgs arg
#   builtins.toJSON (sb.mkTemplate {
#     wgFront  = s.warpEndpoint;             # raw JSON string blob
#     wgBypass = s.wg-bypass;                # extra CIDRs kept on the main table
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

  # transparent TUN inbound. auto_route is OFF on purpose — chproxy owns system
  # routing (`chproxy tun on` installs the policy table pointing here). The
  # device itself is created unconditionally, so the interface always exists
  # whenever the template is active.
  #
  # stack MUST be gvisor: the system/mixed stacks re-inject TCP through the
  # kernel, which without auto_route's escape rules loops straight back into
  # the tun (observed: UDP answered via gvisor, TCP silently blackholed).
  # gvisor terminates everything in userspace, so manual policy routing works.
  tun-inbound = {
    type = "tun";
    tag = "tun-in";
    address = [ "198.18.0.1/16" ];
    interface_name = "throne-tun";
    mtu = 1500;
    stack = "gvisor";
    auto_route = false;
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

  # The remote resolver rides the wg front ("wire") in udp mode — the shape the
  # old `-w` branch used, now baked in: main.json's exit is ALWAYS the front
  # (front detours through the carrier); `chproxy wg on/off` only decides
  # whether *system* traffic is policy-routed into it. A hand-written template
  # without a front would point these at its own exit instead.
  dns-remote = {
    server = "8.8.8.8";
    domain_resolver = "dns-local";
    tag = "dns-remote";
    type = "udp";
    detour = "wire";
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

  # sniff the first hop, then steal DNS for the resolver.
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

  # RFC1918 + loopback — always kept off the tunnels (kernel-level `to <cidr>
  # lookup main` bypass rules) so LAN, Docker bridge networks and localhost
  # still reach the host directly. This replaces both the old tun
  # route_exclude_address and the sing-box-level direct_private_rule.
  private-bypass = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "127.0.0.0/8"
  ];

  # structural overlay turning any raw wg endpoint into a carrier-riding system
  # tunnel. Idempotent on blobs that already carry these fields.
  system-wg-struct = {
    system = true;
    name = "www";
    detour = "proxy";
    tag = "wire";
  };
in
{
  # Build a /etc/chproxy/<name>.json template for this profile.
  #   wgFront != null → the "main" shape: mixed + tun inbounds + the wg front
  #     as the sing-box exit (route.final "wire", front detours the carrier).
  #   wgFront == null → the "plain" shape: carrier-direct exit (route.final
  #     "proxy", no endpoint, no x-chproxy.wg) — the reliable mode for
  #     carriers that can't carry the front's UDP (e.g. socks) or when the
  #     front itself is down.
  # `wgBypass` is the extra CIDRs every system-wg tunnel must keep on the main
  # table (caller-supplied, since it carries server IPs). chproxy adds the
  # carrier's own IP on top at runtime. The tunnel tables/marks are
  # policy-routing facts other services depend on (the james specialisation
  # binds fwmark 521 → table 123 @1000), so the defaults below must not drift.
  mkTemplate =
    {
      wgFront ? null,
      wgBypass ? [ ],
      table ? 123,
      fwmark ? 520,
      interface ? "www",
      tunTable ? 124,
      tunInterface ? "throne-tun",
      # nameservers the tunnels pin /etc/resolv.conf to (exclusively, via
      # resolvconf) — must be public IPs so they ride the policy-routed tunnel
      # instead of leaking out the main table.
      dns ? [
        "1.1.1.1"
        "1.0.0.1"
      ],
    }:
    {
      # ── chproxy routing metadata (stripped before sing-box sees this) ──
      # fwmark is the sing-box INSTANCE identity (rendered into
      # route.default_mark below): sing-box marks its own dials, and
      # `fwmark <fwmark> lookup main` lets them escape the policy table — the
      # anti-recursion that also covers domain-server carriers whose IP can't
      # be bypass-listed. One mark serves both tunnels (they are mutually
      # exclusive). 521 is the james tailscale instance → table 123; do not
      # reuse either value for anything else.
      x-chproxy = {
        tun = {
          interface = tunInterface;
          table = tunTable;
          inherit fwmark dns;
          bypass = private-bypass;
        };
      }
      // (if wgFront == null then { } else {
        # no endpoint → no www interface → `chproxy wg on` is unavailable
        wg = {
          inherit interface table fwmark dns;
          # same list the old script built at runtime: extra bypasses first,
          # then RFC1918/loopback
          bypass = wgBypass ++ private-bypass;
        };
      });

      certificate = {
        store = "system";
      };
      log = {
        level = "info";
      };

      dns = {
        rules = localhost-dns-rules;
        servers = [
          # plain shape: DoH to 8.8.8.8 over :443 through the carrier — DoT
          # (:853) gets reset by port-restricted carriers (e.g. the LAN socks).
          # front shape: udp through "wire". Either way carrier-domain
          # bootstrap goes via dns-direct (see route below).
          (
            if wgFront == null then
              dns-remote // {
                type = "https";
                detour = "proxy";
              }
            else
              dns-remote
          )
          dns-direct
          dns-local
        ];
      };

      inbounds = [
        mixed-inbound
        tun-inbound
      ];

      endpoints =
        if wgFront == null then
          [ ]
        else
          [ ((read wgFront) // system-wg-struct) ];

      # "proxy" is the carrier placeholder — chproxy replaces it with the
      # selected carrier (wireguard-type carriers land in endpoints instead).
      outbounds = [
        {
          type = "direct";
          tag = "proxy";
        }
        {
          type = "direct";
          tag = "direct";
        }
      ];

      route = {
        rules = [
          sniff-rule
          hijack-dns-rule
        ];
        final = if wgFront == null then "proxy" else "wire";
        find_process = false;
        rule_set = [ ];
        # Bootstrap resolution (carrier server domains, etc.) must NOT ride
        # the front: wire detours "proxy", whose own domain would then need
        # resolving again → deadlock for domain-server carriers. dns-direct
        # (plain UDP 223.5.5.5, direct) breaks the circle — the old no-front
        # path did the same.
        default_domain_resolver = {
          server = "dns-direct";
          strategy = "";
        };
        default_mark = fwmark;
      };

      inherit experimental;
    };

  # Build /etc/chproxy/settings.json — the globals chproxy falls back to when
  # /etc/chproxy/state.json is absent. `defaultProxy` is what the legacy
  # "default" resolves to (a key in the runtime /etc/proxies.json).
  mkSettings =
    {
      defaultProxy,
      defaultTemplate ? "main",
      service ? "chproxy",
      singboxBin ? "sing-box",
      proxiesFile ? "/etc/proxies.json",
      stateFile ? "/etc/chproxy/state.json",
    }:
    {
      inherit service;
      singbox_bin = singboxBin;
      proxies_file = proxiesFile;
      state_file = stateFile;
      defaults = {
        template = defaultTemplate;
        proxy = defaultProxy;
      };
    };
}
