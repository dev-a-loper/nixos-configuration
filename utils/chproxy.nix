# chproxy — the sing-box switcher, packaged.
#
# The program itself is a plain bash file at ./chproxy/chproxy (no Nix syntax,
# editor-highlightable, shellcheck-able). This derivation just turns it into a
# `chproxy` bin with the few runtime tools it shells out to on PATH.
#
# `sing-box` is passed in explicitly (the custom 1.14.0-alpha build defined in
# system/network.nix) so the wrapper uses that exact binary. `sudo` and
# `systemctl` are deliberately NOT in runtimeInputs: they come from the system
# PATH (the setuid /run/wrappers/bin/sudo and systemd's systemctl), and adding
# nixpkgs `sudo` here would shadow the setuid wrapper and break escalation.
{
  writeShellApplication,
  sing-box,
  jq,
  iproute2,
}:
writeShellApplication {
  name = "chproxy";
  # The daemon's flow is conditional (wait loops, optional wg routing), so we
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
  ];
  text = builtins.readFile ./chproxy/chproxy;
}
