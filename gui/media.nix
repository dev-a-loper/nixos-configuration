{ pkgs, unstable, ... }:
{
  imports = [ ];
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
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
}
