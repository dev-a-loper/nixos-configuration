{ pkgs, unstable, ... }:
{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  environment.systemPackages = with pkgs; [
    mkvtoolnix
    ffmpeg-full
    vlc
    popcorntime
    unstable.yt-dlp
    unstable.yt-dlg
  ];
  services.galene = {
    httpAddress = "0.0.0.0";
    enable = true;
    insecure = true;
    groupsDir =
      toString (
        pkgs.writeTextDir "groups/public.json" ''
          {
            "description": "Public",
            "public": true,
            "allow-anonymous": true,
            "wildcard-user": {
              "password": {"type": "wildcard"},
              "permissions": "present"
            }
          }
        ''
      )
      + "/groups";
  };
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
}
