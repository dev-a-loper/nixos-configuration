# chproxy

The sing-box switcher: templates + carriers, tunneling decoupled. Plain bash
+ jq — the header of [`./chproxy`](./chproxy) is the full contract (layout,
carriers, tunnels, the fwmark escape and its reply side, `escape`, the DNS
pin).

```
chproxy use <proxy>                 switch carrier (keeps the template)
chproxy use <template> <proxy>      switch template + carrier
chproxy tun on|off / wg on|off      policy-route system traffic into a tunnel
chproxy list | status | compose
```

## Package

```
nix run github:<owner>/chproxy
```

`packages.<system>.default` (`chproxy`) is built with `sing-box-extended`
(the [shtorm-7 fork](https://github.com/shtorm-7/sing-box-extended), the one
templates are authored against; also exported as `packages.<system>.sing-box-extended`).

## NixOS module

```nix
inputs.chproxy.url = "github:<owner>/chproxy";
inputs.chproxy.inputs.nixpkgs.follows = "nixpkgs";
```

```nix
modules = [ chproxy.nixosModules.default ];
```

```nix
services.chproxy = {
  enable = true;
  # name → COMPLETE sing-box config + the reserved "x-chproxy" {tun,wg}
  # section, rendered 1:1 to /etc/chproxy/<name>.json
  templates.main = { … };
  # default carrier — a key in the carrier list
  settings.defaults.proxy = "vps";
  # optional: declare the carriers too (otherwise: runtime /etc/proxies.json)
  # proxies = { vps = { … }; };
};
```

The module provides the `chproxy` unit, `/etc/chproxy/{settings,<template>}.json`,
the CLI and sing-box on PATH, and — on by default when `services.tailscale`
is — the escape that keeps tailscale alive through a tunnel
(`services.chproxy.escape.tailscale`). Turn on `services.chproxy.ipv4Only`
when a template has a tunnel: they policy-route IPv4 only, so any IPv6 path
would bypass them.

`./example` is a minimal, buildable reference (`nixos-rebuild build --flake .#example`).
