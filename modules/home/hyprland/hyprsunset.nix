{
  # Blue-light filter. Runs as a user unit bound to the wayland session so the
  # AGS monitor popover always has a daemon to talk to — its colour-temperature
  # slider drives `hyprctl hyprsunset`, which needs the socket to exist.
  services.hyprsunset = {
    enable = true;

    # Starts NEUTRAL, not filtered. 6500K is sRGB's D65 white point, so enabling
    # this changes nothing on screen until the slider is moved; the point here is
    # to have the control available, not to tint the desktop at login.
    #
    # Deliberately not `--identity`: that applies no transform but leaves the
    # daemon reporting its built-in 6000K default, so the slider would open
    # claiming a filter that is not actually applied. Setting a real temperature
    # keeps what it reports and what it renders the same thing.
    extraArgs = [
      "-t"
      "6500"
    ];

    # No `settings` on purpose — that writes hypr/hyprsunset.conf with timed
    # profiles, and a scheduled change would move the temperature behind the
    # bar's back. service/sunset.ts re-reads only when the popover opens, which
    # is enough while this stays manual.
  };
}
