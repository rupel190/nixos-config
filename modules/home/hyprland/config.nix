{ ... }:
{
  wayland.windowManager.hyprland = {
    settings = {
      # autostart
      exec-once = [
        # "nm-applet &"
        # "poweralertd &"
        # "wl-clip-persist --clipboard both &"
        # "wl-paste --watch cliphist store &"
        "swaync &"
        "hyprctl setcursor catppuccin-macchiato-yellow-cursors 24 &"

        # TODO: Add AGS startup here
        # "ags &"

        "hyprlock"

        # https://wiki.hypr.land/FAQ/#fullscreen-applicationssteam-games-open-with-secondary-monitors-resolution
        # Not sure it works on wayland
        "xrandr --output DP-2 --primary"
        # Auth daemon for GUI apps requesting privilege elevation
        "systemctl --user start hyprpolkitagent"
        # which to choose?
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        # which to choose?
        "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        # exec-once = hyprpaper			# Wallpaper
        "hyprsunset" # Blue light & gamma (brightness) filter # Also see for IPC through hyperctl: https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/#ipc
        "hypridle" # Needs env vars to find its own config
        #hyprpm reload   # Hypr plugin manager (Mouse cursor etc.)
        #ianny					# Reminder utility for taking screen breaks
      ];

      #TODO: not sure which to keep
      input = {
        kb_layout = "us,de";
        # kb_options = "grp:alt_caps_toggle";
        numlock_by_default = true;
        follow_mouse = 0; # -> true?
        float_switch_override_focus = 0;
        mouse_refocus = 0;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
        };
      };

      #TODO: not sure about defaults and which to keep
      general = {
        "$mainMod" = "SUPER";
        layout = "dwindle";
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgb(98971A) rgb(CC241D) 45deg";
        "col.inactive_border" = "0x00000000";
        border_part_of_window = false;
        no_border_on_floating = false;
      };

      #TODO: same
      misc = {
        disable_autoreload = true;
        disable_hyprland_logo = true;
        always_follow_on_dnd = true;
        layers_hog_keyboard_focus = true;
        animate_manual_resizes = false;
        enable_swallow = true;
        focus_on_activate = true;
        new_window_takes_over_fullscreen = 2;
        middle_click_paste = false;
      };

      #TODO: ssame
      dwindle = {
        # no_gaps_when_only = false;
        force_split = 0;
        special_scale_factor = 1.0;
        split_width_multiplier = 1.0;
        use_active_for_splits = true;
        pseudotile = "yes";
        preserve_split = "yes";
      };

      #TODO: same
      master = {
        new_status = "master";
        special_scale_factor = 1;
        # no_gaps_when_only = false;
      };

      #TODO: same
      decoration = {
        rounding = 0;
        # active_opacity = 0.90;
        # inactive_opacity = 0.90;
        # fullscreen_opacity = 1.0;

        blur = {
          enabled = true;
          size = 3;
          passes = 2;
          brightness = 1;
          contrast = 1.4;
          ignore_opacity = true;
          noise = 0;
          new_optimizations = true;
          xray = true;
        };

        shadow = {
          enabled = true;

          ignore_window = true;
          offset = "0 2";
          range = 20;
          render_power = 3;
          color = "rgba(00000055)";
        };
      };

      animations = {
        enabled = true;

        bezier = [
          "fluent_decel, 0, 0.2, 0.4, 1"
          "easeOutCirc, 0, 0.55, 0.45, 1"
          "easeOutCubic, 0.33, 1, 0.68, 1"
          "fade_curve, 0, 0.55, 0.45, 1"
        ];

        animation = [
          # name, enable, speed, curve, style

          # Windows
          "windowsIn,   0, 4, easeOutCubic,  popin 20%" # window open
          "windowsOut,  0, 4, fluent_decel,  popin 80%" # window close.
          "windowsMove, 1, 2, fluent_decel, slide" # everything in between, moving, dragging, resizing.

          # Fade
          "fadeIn,      1, 3,   fade_curve" # fade in (open) -> layers and windows
          "fadeOut,     1, 3,   fade_curve" # fade out (close) -> layers and windows
          "fadeSwitch,  0, 1,   easeOutCirc" # fade on changing activewindow and its opacity
          "fadeShadow,  1, 10,  easeOutCirc" # fade on changing activewindow for shadows
          "fadeDim,     1, 4,   fluent_decel" # the easing of the dimming of inactive windows
          # "border,      1, 2.7, easeOutCirc"  # for animating the border's color switch speed
          # "borderangle, 1, 30,  fluent_decel, once" # for animating the border's gradient angle - styles: once (default), loop
          "workspaces,  1, 4,   easeOutCubic, fade" # styles: slide, slidevert, fade, slidefade, slidefadevert
        ];
      };

      windowrule = [
        # See https://wiki.hyprland.org/Configuring/Window-Rules/
        # See https://wiki.hyprland.org/Configuring/Workspace-Rules/

        # Fix some dragging issues with XWayland
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"

        # Ignore maximize requests from apps. TODO: Good idea?
        "suppressevent maximize, class:.*"

        # CS2 tweak, https://wiki.hypr.land/Configuring/Tearing/#enabling-tearing
        "immediate, class:^(cs2)$"
        # "float,Viewnior"
        # "float,imv"
        # "float,mpv"
        # "tile,Aseprite"
        # "float,audacious"
        # "tile, neovide"
        # "idleinhibit focus,mpv"
        # "float,udiskie"
        # "float,title:^(Transmission)$"
        # "float,title:^(Volume Control)$"
        # "float,title:^(Firefox — Sharing Indicator)$"
        # "move 0 0,title:^(Firefox — Sharing Indicator)$"
        # "size 700 450,title:^(Volume Control)$"
        # "move 40 55%,title:^(Volume Control)$"
      ];

      windowrulev2 = [
        "workspace 4 silent, class:^(app.zen_browser.zen)$"
        "workspace 4, class:^(zen)$"
        "workspace 7 silent, class:^(ticktick|Proton Mail|Slack|class.org.keepassxc.KeePassXC)$"
        "workspace 8 silent, class:^(discord|Signal)$"
        "workspace 9 silent, class:^(Spotify)$"

        "float, title:^(Picture-in-Picture)$"
        "opacity 1.0 override 1.0 override, title:^(Picture-in-Picture)$"
        "pin, title:^(Picture-in-Picture)$"
        "opacity 1.0 override 1.0 override, title:^(.*imv.*)$"
        "opacity 1.0 override 1.0 override, title:^(.*mpv.*)$"
        "opacity 1.0 override 1.0 override, class:(Aseprite)"
        "opacity 1.0 override 1.0 override, class:(Unity)"
        "opacity 1.0 override 1.0 override, class:(zen)"
        "opacity 1.0 override 1.0 override, class:(evince)"
        "idleinhibit focus, class:^(mpv)$"
        "idleinhibit fullscreen, class:^(firefox)$"
        "float,class:^(org.gnome.Calculator)$"
        "float,class:^(waypaper)$"
        "float,class:^(zenity)$"
        "size 850 500,class:^(zenity)$"
        "size 725 330,class:^(SoundWireServer)$"
        "float,class:^(org.gnome.FileRoller)$"
        "float,class:^(pavucontrol)$"
        "float,class:^(SoundWireServer)$"
        "float,class:^(.sameboy-wrapped)$"
        "float,class:^(file_progress)$"
        "float,class:^(confirm)$"
        "float,class:^(dialog)$"
        "float,class:^(download)$"
        "float,class:^(notification)$"
        "float,class:^(error)$"
        "float,class:^(confirmreset)$"
        "float,title:^(Open File)$"
        "float,title:^(File Upload)$"
        "float,title:^(branchdialog)$"
        "float,title:^(Confirm to replace files)$"
        "float,title:^(File Operation Progress)$"

        "opacity 0.0 override,class:^(xwaylandvideobridge)$"
        "noanim,class:^(xwaylandvideobridge)$"
        "noinitialfocus,class:^(xwaylandvideobridge)$"
        "maxsize 1 1,class:^(xwaylandvideobridge)$"
        "noblur,class:^(xwaylandvideobridge)$"

        # No gaps when only
        "bordersize 0, floating:0, onworkspace:w[t1]"
        "rounding 0, floating:0, onworkspace:w[t1]"
        "bordersize 0, floating:0, onworkspace:w[tg1]"
        "rounding 0, floating:0, onworkspace:w[tg1]"
        "bordersize 0, floating:0, onworkspace:f[1]"
        "rounding 0, floating:0, onworkspace:f[1]"

        # "maxsize 1111 700, floating: 1"
        # "center, floating: 1"

        # Remove context menu transparency in chromium based apps
        "opaque,class:^()$,title:^()$"
        "noshadow,class:^()$,title:^()$"
        "noblur,class:^()$,title:^()$"
      ];

      # No gaps when only
      workspace = [
        "w[t1], gapsout:0, gapsin:0"
        "w[tg1], gapsout:0, gapsin:0"
        "f[1], gapsout:0, gapsin:0"
      ];
    };

    extraConfig = "
      monitor=,preferred,auto,auto

      xwayland {
        force_zero_scaling = true
      }
    ";
  };
}
