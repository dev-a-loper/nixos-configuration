{
  config,
  pkgs,
  lib,
  ...
}:
let
  userName = config.userConfiguration.name;
in
{
  home-manager.users.${userName}.home.pointerCursor.size = lib.mkForce 128;
  console.font = pkgs.lib.mkForce "Lat2-Terminus32";

}
