# chproxy — the sing-box switcher, packaged.
#
# The program itself is a plain bash file at ./chproxy (no Nix syntax,
# editor-highlightable, shellcheck-able). This derivation just turns it into a
# `chproxy` bin with the few runtime tools it shells out to on PATH — every
# argument is callPackage-resolvable, so the package builds standalone:
#   nix run github:<this-repo>#chproxy
#
# `sudo` and `systemctl` are deliberately NOT in runtimeInputs: they come from
# the system PATH (the setuid /run/wrappers/bin/sudo and systemd's systemctl),
# and adding nixpkgs `sudo` here would shadow the setuid wrapper and break
# escalation. system/network.nix passes its pinned sing-box via override.
{
  writeShellApplication,
  sing-box,
  jq,
  iproute2,
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
    openresolv # resolvconf — DNS leak pin while a tunnel is up
  ];
  text = builtins.readFile ./chproxy;
}
