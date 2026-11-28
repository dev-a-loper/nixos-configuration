# Reference configuration for the chproxy module: minimal and buildable
# (`nixos-rebuild build --flake .#example`) — doubles as the module's test.
{
  modulesPath,
  lib,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/minimal.nix") ];

  # a throwaway system: nothing boots it
  boot.loader.grub.enable = false;
  system.stateVersion = lib.trivial.release;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };

  services.chproxy = {
    enable = true;
    # the tun below policy-routes IPv4 only — no v6 path may bypass it
    ipv4Only = true;

    templates.main = {
      log.level = "warn";
      inbounds = [
        {
          type = "socks";
          tag = "socks-in";
          listen = "127.0.0.1";
          listen_port = 1080;
        }
        {
          type = "tun";
          tag = "tun-in";
          interface_name = "tun0";
          address = [ "172.19.0.1/30" ];
          # chproxy owns the policy routing (x-chproxy.tun below)
          auto_route = false;
          strict_route = false;
        }
      ];
      outbounds = [
        {
          type = "direct";
          tag = "direct";
        }
        # the placeholder the selected carrier replaces
        {
          type = "direct";
          tag = "proxy";
        }
      ];
      route = {
        rules = [
          {
            inbound = [
              "socks-in"
              "tun-in"
            ];
            outbound = "proxy";
          }
        ];
        final = "direct";
      };
      # routing metadata chproxy strips before sing-box sees the config
      "x-chproxy".tun = {
        interface = "tun0";
        table = 100;
        fwmark = 520;
        dns = [ "1.1.1.1" ];
        bypass = [
          "192.168.0.0/16"
          "10.0.0.0/8"
        ];
      };
    };

    # carriers, declared here instead of a runtime /etc/proxies.json
    proxies = {
      # placeholder credentials — a real carrier goes here
      vps = {
        type = "shadowsocks";
        server = "203.0.113.1";
        server_port = 8388;
        method = "2022-blake3-aes-128-gcm";
        password = "8JCsPssfgS8xyRUzCq91eQ==";
      };
    };
    settings.defaults.proxy = "vps";
  };
}
