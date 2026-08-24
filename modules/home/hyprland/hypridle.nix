{ ... }:
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock --grace 0"; # Don't spawn multiple instances on repeated lock signals
        before_sleep_cmd = "loginctl lock-session && sleep 1"; # Lock before suspend; the sleep holds hypridle's inhibitor until hyprlock has painted
        after_sleep_cmd = "hyprctl dispatch dpms on"; # Re-enable monitors after wake
      };
      # Lock BEFORE dpms off: a non-scanning-out output gets no frame callbacks,
      # so a hyprlock started while the panels are dark can't paint until wake.
      listener = [
        {
          timeout = 300; # 5 minutes: lock screen
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 360; # +60s: monitors off, once hyprlock has painted
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
