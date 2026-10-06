{ ... }:
{
  # rtkit - Real-time scheduling for PipeWire (prevents audio crackling)
  security.rtkit.enable = true;

  # PAM service for hyprlock (screen locker authentication)
  security.pam.services.hyprlock = { };

  # oo7: non-GNOME Secret Service (keyring); pam_oo7 on `login` also covers greetd, which includes it
  services.oo7.enable = true;
}
