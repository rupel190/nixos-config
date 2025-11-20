{ pkgs, lib, ... }:
{
  services = {
    gvfs.enable = true;
    # TODO: why udev and dbus?
    udev.enable = true;
    dbus.enable = true;

    # TODO: Helpful? Move to GPU definitions?
    xserver.videoDrivers = lib.mkForce [ "amdgpu" ];

    # ???
    # fstrim.enable = true;

    # TODO: Probably useless
    # needed for GNOME services outside of GNOME Desktop
    # dbus.packages = with pkgs; [
    #   gcr
    #   gnome-settings-daemon
    # ];
  };

  # services.logind.extraConfig = ''
  #   # don’t shutdown when power button is short-pressed
  #   HandlePowerKey=ignore
  # '';
}
