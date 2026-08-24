{ ... }:
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock --grace 0"; # Don't spawn multiple instances on repeated lock signals
        before_sleep_cmd = "loginctl lock-session && sleep 1"; # Lock before suspend; the sleep holds hypridle's inhibitor until hyprlock has painted
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms(\"on\")'"; # Re-enable monitors after wake
      };
      # Lock BEFORE dpms off: a non-scanning-out output gets no frame callbacks,
      # so a hyprlock started while the panels are dark can't paint until wake.
      listener = [
        {
          timeout = 300; # 5 minutes: lock screen
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 600; # 10 minutes: monitors off, long after hyprlock has painted
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms(\"off\")'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms(\"on\")'";
        }
      ];
    };
  };
}
