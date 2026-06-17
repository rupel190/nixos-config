{ pkgs, lib, ... }:
{
  services = {
    gvfs.enable = true;
    udev = {
      enable = true;
      packages = [ pkgs.libmtp ]; # Android MTP connection
    };
    dbus.enable = true;

    xserver.videoDrivers = lib.mkForce [ "amdgpu" ];

    # SSD TRIM service (weekly optimization)
    fstrim.enable = true;

    # ZeroTier
    zerotierone = {
      enable = true;
    };

    # SSH server
    openssh = {
      enable = true;
      openFirewall = true;
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "no";
    };
  };

  # NOTE: Uncomment for laptop - prevents shutdown on power button short-press
  # services.logind.extraConfig = ''
  #   HandlePowerKey=ignore
  # '';
}
