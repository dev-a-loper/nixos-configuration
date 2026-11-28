# chproxy — the sing-box switcher, packaged.
#
# The program itself is a plain bash file at ./chproxy (no Nix syntax,
# editor-highlightable, shellcheck-able). This derivation just turns it into a
# `chproxy` bin with the few runtime tools it shells out to on PATH — every
# argument is callPackage-resolvable, so the package builds standalone:
#   nix run github:<this-repo>#chproxy
#
# `sing-box` defaults to nixpkgs' build. The NixOS module (nixos/default.nix)
# and this flake's own `chproxy` package pass sing-box-extended
# (sing-box-extended.nix) instead — the fork the templates are authored
# against.
#
# `sudo` and `systemctl` are deliberately NOT in runtimeInputs: they come from
# the system PATH (the setuid /run/wrappers/bin/sudo and systemd's systemctl),
# and adding nixpkgs `sudo` here would shadow the setuid wrapper and break
# escalation.
{
  writeShellApplication,
  sing-box,
  jq,
  iproute2,
  nftables,
  openresolv,
}:
writeShellApplication {
  name = "chproxy";
  # The daemon's flow is conditional (wait loops, optional tunnels), so we
  # run with nounset + pipefail but NOT errexit — the script handles errors
  # explicitly with `|| die` / `|| true`.
  bashOptions = [
    "nounset"
    "pipefail"
  ];
  runtimeInputs = [
    sing-box
    jq
    iproute2
    nftables # reply side of the fwmark escape — conntrack-mark table per tunnel
    openresolv # resolvconf — DNS leak pin while a tunnel is up
  ];
  text = builtins.readFile ./chproxy;
}
