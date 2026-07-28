{ pkgs, ... }:
let
  # Upstream's only selection cue is A_BOLD — near-invisible at a glance.
  # Reverse-video the focused name/volume label instead, but mask A_REVERSE back
  # off the gradient bar so filled-vs-empty stays readable on the focused row.
  pulsemixer = pkgs.pulsemixer.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace pulsemixer \
        --replace-fail \
          "focus_hl = bracket_hl = curses.A_BOLD" \
          "focus_hl = bracket_hl = curses.A_BOLD | curses.A_REVERSE" \
        --replace-fail \
          "focus_hl = curses.A_BOLD" \
          "focus_hl = curses.A_BOLD | curses.A_REVERSE" \
        --replace-fail \
          "volbar += '\n{}|{}'.format(v, gradient[i] | focus_hl)" \
          "volbar += '\n{}|{}'.format(v, gradient[i] | (focus_hl & ~curses.A_REVERSE))"
    '';
  });
in
{
  home.packages = [ pulsemixer ];

  xdg.configFile."pulsemixer.cfg".text = ''
    [general]
    step = 1
    step-big = 10

    [ui]
    color = 2
    mouse = yes

    [style]
    ;; Solid blocks flank the focused device's bar on every channel row
    arrow         = ' '
    arrow-focused = █
    arrow-locked  = █
  '';
}
