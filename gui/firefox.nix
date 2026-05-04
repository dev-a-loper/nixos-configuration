{ config, pkgs, ... }:
let
  userName = config.userConfiguration.name;
in
{
  home-manager.users.${userName}.programs.firefox = {
    enable = true;
    package = pkgs.wrapFirefox pkgs.firefox-bin-unwrapped {
      extraPolicies = {
        CaptivePortal = false;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DisableFirefoxAccounts = false;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = true;
        OfferToSaveLoginsDefault = true;
        PasswordManagerEnabled = true;
        FirefoxHome = {
          Search = true;
          Pocket = false;
          Snippets = false;
          TopSites = false;
          Highlights = false;
        };
        UserMessaging = {
          ExtensionRecommendations = false;
          SkipOnboarding = true;
        };
      };
    };
    profiles.default = {
      name = "default";
      path = "default";
      id = 0;

      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        bitwarden
        tridactyl
        zeroomega
      ];
      isDefault = true;
      search.default = "ddg";
      search.force = true;
      settings = {
        "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
      };
    };
  };
  environment.systemPackages = [ pkgs.firefox ];
}
