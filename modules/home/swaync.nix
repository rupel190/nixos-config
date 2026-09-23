{ ... }:
let
  # Catppuccin Macchiato, the same values as modules/home/ags/style.scss and the
  # GTK theme in gtk.nix. Duplicated as literals rather than shared because the
  # bar's copy lives in SCSS and there is no build step joining the two — if one
  # moves, grep the hex.
  mantleRGB = "30, 32, 48"; # #1e2030 — bare triple, see --noti-bg below
  surface0 = "54, 58, 79"; # #363a4f
  surface1 = "73, 77, 100"; # #494d64
  text = "#cad3f5";
  subtext0 = "#a5adcb";
  overlay1 = "#8087a2";
  teal = "#8bd5ca";

  # Matches window.Bar in ags/style.scss. Pango falls back per glyph, so a Nerd
  # Font icon inside a notification body still renders while the prose stays in
  # Geist.
  fontStack = ''"Geist", "MonaspiceXe Nerd Font Mono", "Geist Mono", sans-serif'';
in
{
  services.swaync = {
    enable = true;

    # Themed to sit in the same family as the AGS bar and as Hyprland's own
    # notification overlay (the toast `audio-switch` raises).
    #
    # ⚠️ Hyprland's overlay is NOT themeable and cannot be made to match exactly.
    # src/notification/NotificationOverlay.cpp hardcodes the background to black
    # and the text to white, draws plain unrounded rects, and fixes padding and
    # position as compile-time constants. Its only levers are misc:font_family
    # (set in hyprland/config.nix), the accent colour passed per notification,
    # and an icon index. So the shared language is the FONT, the TEAL ACCENT and
    # a very dark ground — not the corner radius, which stays square there and
    # rounded here to match the bar's own popovers.
    style = ''
      /* Overrides only. swaync loads the packaged stylesheet and THEN this one,
         unconditionally and in that order (functions.vala:104 then :117), so the
         561 lines of upstream node-tree selectors are already in effect and
         everything worth recolouring is reachable through the :root custom
         properties they read. An @import of the packaged sheet here is a second
         copy of what is already loaded — verified by running the daemon against
         this file with the import stripped: nothing lost its styling. */
      :root {
        /* Composed as rgba(var(--noti-bg), var(--noti-bg-alpha)) upstream, so
           this has to stay a bare comma triple rather than a colour. */
        --noti-bg: ${mantleRGB};
        /* Denser than .bar-inner's 0.78, and deliberately so: the bar sits on a
           fixed strip of mostly-dark desktop, while a notification lands on top
           of whatever happens to be on screen. At 0.78 a toast over a bright
           image was legible but visibly grubby. Hyprland still frosts what is
           behind it via the swaync layer_rule in hyprland/config.nix, so it
           keeps the bar's material without borrowing its colour. */
        --noti-bg-alpha: 0.92;
        --noti-bg-darker: rgba(${mantleRGB}, 0.92);
        --noti-bg-hover: rgba(${surface1}, 0.5);
        --noti-bg-focus: rgba(${surface1}, 0.6);
        --noti-border-color: rgba(${surface0}, 0.9);
        --noti-close-bg: rgba(${surface1}, 0.5);
        --noti-close-bg-hover: rgba(${surface1}, 0.75);

        /* The panel keeps the bar's lighter 0.78: it is a large fixed surface
           you open deliberately, not a toast that has to stay readable wherever
           it lands. */
        --cc-bg: rgba(${mantleRGB}, 0.78);
        --text-color: ${text};
        --text-color-disabled: ${overlay1};
        --bg-selected: ${teal};

        /* The AGS popover radius, not the bar's 8px: a notification is a
           floating surface, and popover > contents is the closest sibling. */
        --border-radius: 10px;
        /* The compositor blurs behind this now, and a drop shadow on top of a
           frosted surface reads as grime. */
        --notification-shadow: none;
        --font-size-summary: 14px;
        --font-size-body: 13px;
      }

      .control-center,
      .notification-row,
      .floating-notifications {
        font-family: ${fontStack};
      }

      /* The one deliberate echo of Hyprland's overlay, which paints a 5px bar of
         the notification's colour down its left edge. Same width, same teal as
         the accent `audio-switch` passes to hyprctl notify. */
      .notification-row .notification-background .notification {
        border-left: 5px solid ${teal};
      }

      /* Summary bright, body recessed — the same two-level hierarchy the bar
         uses for .Clock .hm against .Clock .date. Upstream paints both at full
         contrast, which flattens them into one block. */
      .notification-row
        .notification-background
        .notification
        .notification-default-action
        .notification-content
        .text-box
        .body {
        color: ${subtext0};
      }

      .notification-row
        .notification-background
        .notification
        .notification-default-action
        .notification-content
        .text-box
        .time {
        color: ${overlay1};
        font-weight: normal;
      }
    '';
  };
}
