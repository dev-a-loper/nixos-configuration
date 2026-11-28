# chproxy — NixOS module (`services.chproxy`).
#
# Everything the switcher needs on a system: the daemon unit, the rendered
# templates + settings under /etc/chproxy, the (optional) carrier list, the
# escape that keeps other VPNs alive through a tunnel, and the CLI on PATH.
# The templates stay plain data — complete sing-box configs plus the reserved
# x-chproxy {tun,wg} routing section (the contract is in the header of
# ../chproxy). There is deliberately no template engine: a host differs by
# writing its own template.
#
# State (settings.state_file) is writable runtime data — never an
# environment.etc store symlink.
{ src }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.chproxy;

  sing-box-extended = pkgs.callPackage "${src}/sing-box-extended.nix" { };
  chproxy = pkgs.callPackage "${src}/package.nix" { sing-box = cfg.sing-box; };

  # names the CLI reserves for its own files
  reservedTemplates = [
    "state"
    "settings"
    "chproxy"
  ];
  templateFiles = lib.mapAttrs (
    name: template: pkgs.writeText "chproxy-${name}.json" (builtins.toJSON template)
  ) cfg.templates;

  # Other VPNs that must survive a tunnel (the "other VPNs" paragraph in the
  # script header). A tunnel's catch-all @2000 would otherwise swallow the
  # rules of any router sitting at a higher priority number — tailscale's
  # (5210…5270) included, i.e. both tailscaled's own traffic and the tailnet.
  # chproxy installs these at @900, in front of the catch-all.
  escape = {
    marks = cfg.escape.marks ++ lib.optionals cfg.escape.tailscale [ "0x80000/0xff0000" ];
    routes =
      cfg.escape.routes
      ++ lib.optionals cfg.escape.tailscale [
        {
          to = "100.64.0.0/10";
          table = 52;
        }
      ];
  };
  settingsJson = pkgs.writeText "chproxy-settings.json" (
    builtins.toJSON (
      cfg.settings
      // {
        # rendered only when non-empty, like the script reads it
        escape = lib.optionalAttrs (escape.marks != [ ] || escape.routes != [ ]) {
          inherit (escape) marks routes;
        };
      }
    )
  );

  # A declared carrier list is rendered into settings.proxies_file, which
  # must then live under /etc; `null` leaves that runtime file alone.
  proxiesJson =
    if cfg.proxies != null then
      pkgs.writeText "chproxy-proxies.json" (builtins.toJSON cfg.proxies)
    else
      null;
  # environment.etc keys are relative to /etc (the assertion guards the prefix)
  proxiesEtc = lib.optionalString (proxiesJson != null) (
    lib.removePrefix "/etc/" cfg.settings.proxies_file
  );
in
{
  options.services.chproxy = {
    enable = lib.mkEnableOption "chproxy, the sing-box switcher";

    package = lib.mkOption {
      type = lib.types.package;
      default = chproxy;
      defaultText = lib.literalExpression "built from this module's source with `sing-box` on its PATH";
      description = "The chproxy package (the CLI — `chproxy` on the system PATH, and what the unit runs).";
    };

    sing-box = lib.mkOption {
      type = lib.types.package;
      default = sing-box-extended;
      defaultText = lib.literalExpression "sing-box-extended (the shtorm-7 fork)";
      description = "sing-box the daemon runs. Also put on the system PATH. Templates are authored against the extended fork.";
    };

    templates = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = ''
        Templates, name → COMPLETE custom sing-box config, rendered 1:1 to
        /etc/chproxy/<name>.json. Two contract points, everything else is
        plain sing-box: the reserved top-level "x-chproxy" {tun,wg} routing
        section (stripped by chproxy before sing-box sees it, drives
        `chproxy tun/wg on`) and the outbound tagged "proxy" — the placeholder
        the selected carrier replaces. Reserved names: state, settings, chproxy.
      '';
    };

    settings = lib.mkOption {
      description = ''
        Globals, rendered to /etc/chproxy/settings.json. The declared keys
        have defaults; anything else is passed through. ("escape" is rendered
        from services.chproxy.escape.)
      '';
      default = { };
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf lib.types.anything;
        options = {
          service = lib.mkOption {
            type = lib.types.str;
            default = "chproxy";
            description = "The systemd unit `chproxy use …` restarts. The module's own unit is named exactly so.";
          };
          singbox_bin = lib.mkOption {
            type = lib.types.str;
            default = "sing-box";
            description = "sing-box executable, by name — resolved on the daemon's PATH.";
          };
          proxies_file = lib.mkOption {
            type = lib.types.str;
            default = "/etc/proxies.json";
            description = "Carrier list, name → outbound. Runtime and user-maintained, unless services.chproxy.proxies declares it.";
          };
          state_file = lib.mkOption {
            type = lib.types.str;
            default = "/etc/chproxy/state.json";
            description = "Runtime state {template, proxy, tun, wg}.";
          };
          defaults = lib.mkOption {
            type = lib.types.submodule {
              options = {
                template = lib.mkOption {
                  type = lib.types.str;
                  default = "main";
                  description = "The template active before anything is selected.";
                };
                proxy = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "The carrier active before anything is selected (a key in the carrier list); null for none.";
                };
              };
            };
            default = { };
            description = "What is active before anything is selected.";
          };
        };
      };
    };

    proxies = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.attrs);
      default = null;
      description = ''
        Carriers to render into settings.proxies_file (which must then live
        under /etc): name → outbound, or endpoint config for wireguard-type
        carriers. null leaves that file alone — edit it at runtime, no
        rebuild.
      '';
    };

    escape = {
      marks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "0x80000/0xff0000" ];
        description = "fwmark selectors (VALUE[/MASK]) whose traffic keeps the main table while a tunnel is up — sockets another VPN marks itself.";
      };
      routes = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              to = lib.mkOption {
                type = lib.types.str;
                description = "Destination prefix that keeps its own routing table.";
              };
              table = lib.mkOption {
                type = lib.types.either lib.types.int lib.types.str;
                description = "The routing table it keeps.";
              };
            };
          }
        );
        default = [ ];
        description = "Destinations that must not be swallowed by a tunnel.";
      };
      tailscale = lib.mkOption {
        type = lib.types.bool;
        default = config.services.tailscale.enable;
        description = ''
          Keep tailscale alive through a tunnel: tailscaled's own sockets
          (fwmark 0x80000/0xff0000) stay on the main table and the tailnet
          (100.64.0.0/10) in table 52. On whenever services.tailscale is — for
          a host that uses tailscale as an exit node, turn it off.
        '';
      };
    };

    ipv4Only = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Refuse IPv6 egress system-wide. chproxy's tunnels policy-route IPv4
        only, so any v6 path would bypass them (an IP leak): this turns IPv6
        off declaratively (networking.enableIPv6) and with sysctls on all +
        default interfaces — the hard guarantee, future ones included.
      '';
    };
  };

  # Everything below must stay lazy: the module system evaluates `config`
  # to an attrset before `config` exists (import collection), so conditions
  # belong in mkIf / mkMerge — never in a `//` at this level.
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = lib.intersectLists reservedTemplates (builtins.attrNames cfg.templates) == [ ];
            message = "services.chproxy.templates: reserved name(s) ${toString (lib.intersectLists reservedTemplates (builtins.attrNames cfg.templates))}";
          }
          {
            assertion = cfg.settings.service == "chproxy";
            message = "services.chproxy.settings.service: the module only defines the `chproxy` unit, got `${cfg.settings.service}`";
          }
          {
            assertion = proxiesJson == null || lib.hasPrefix "/etc/" cfg.settings.proxies_file;
            message = "services.chproxy: a declared `proxies` is rendered by environment.etc, so settings.proxies_file must live under /etc";
          }
        ];

        # A legacy /etc/current-proxy is migrated by chproxy itself on first run.
        environment.etc = {
          "chproxy/settings.json".source = settingsJson;
        }
        // lib.mapAttrs' (
          name: file: lib.nameValuePair "chproxy/${name}.json" { source = file; }
        ) templateFiles
        // lib.optionalAttrs (proxiesJson != null) { ${proxiesEtc}.source = proxiesJson; };

        environment.systemPackages = [
          cfg.package
          cfg.sing-box
        ];

        systemd.services.chproxy = {
          description = "chproxy — sing-box switcher";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          # environment.etc changes alone don't restart units — the daemon composes
          # its config at START, so a rebuilt template must bounce the service.
          restartTriggers =
            (lib.attrValues templateFiles)
            ++ [
              settingsJson
            ]
            ++ lib.optionals (proxiesJson != null) [ proxiesJson ];
          serviceConfig = {
            Restart = "always";
            # NOTE: an IPMark= here would be silently ignored by systemd
            # ("Unknown key"); sing-box's anti-recursion mark comes from the
            # template's route.default_mark instead.
            ExecStart = "${cfg.package}/bin/chproxy daemon";
          };
          path = [
            cfg.sing-box
            pkgs.jq
            pkgs.iproute2
            # reply side of the fwmark escape: this unit's reverse-path filter
            # (`checkReversePath`) drops unmarked replies to sing-box's marked
            # sockets, so each tunnel carries the mark across conntrack via nft
            pkgs.nftables
            pkgs.openresolv # resolvconf — DNS leak pin while a tunnel is up
          ];
        };
      }
      # No IPv6 egress, ever (see the option). Tailscale falls back to v4 fine.
      (lib.mkIf cfg.ipv4Only {
        networking.enableIPv6 = false;
        boot.kernel.sysctl = {
          "net.ipv6.conf.all.disable_ipv6" = 1;
          "net.ipv6.conf.default.disable_ipv6" = 1;
        };
      })
    ]
  );
}
