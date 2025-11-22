{ ... }:
{
  # rtkit - Real-time scheduling for PipeWire (prevents audio crackling)
  security.rtkit.enable = true;

  # PAM service for hyprlock (screen locker authentication)
  security.pam.services.hyprlock = { };
}
