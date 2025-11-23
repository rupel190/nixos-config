{ pkgs, username, ... }:
{
  services = {
    xserver = {
      enable = true;
      xkb.layout = "us,fr";
    };

    # Auto-login - SECURITY RISK! Skips login screen entirely
    # Disabled for security (enable only on trusted single-user systems)
    # displayManager.autoLogin = {
    #   enable = true;
    #   user = "${username}";
    # };

    libinput = {
      enable = true;
    };
  };
  # To prevent getting stuck at shutdown
  systemd.settings.Manager.DefaultTimeoutStopSec = "10s";
}
