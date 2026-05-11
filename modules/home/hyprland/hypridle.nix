{ ... }:
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock"; # Don't spawn multiple instances on repeated lock signals
        before_sleep_cmd = "loginctl lock-session"; # Lock before suspend
        after_sleep_cmd = "hyprctl dispatch dpms on"; # Re-enable monitors after wake
      };
      listener = [
        {
          timeout = 300; # 5 minutes: turn off monitors
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 600; # 10 minutes: lock screen
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };
}
