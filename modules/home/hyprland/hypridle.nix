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
      # Lock lands on already-dark panels: hyprlock gets no frame callbacks until
      # wake, so the compositor's own lock surface covers the gap (as after a manual blank).
      listener = [
        {
          timeout = 600; # 10 minutes: monitors off
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms(\"off\")'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms(\"on\")'";
        }
        {
          timeout = 1200; # 20 minutes: lock screen
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };
}
