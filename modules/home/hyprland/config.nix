{ host, ... }:
{
  wayland.windowManager.hyprland = {
    settings = {
      # Main modifier key - must be at top level, not in general block
      "$mainMod" = "SUPER";

      # autostart
      exec-once = [
        # "nm-applet &"
        # "poweralertd &"
        # "wl-clip-persist --clipboard both &"
        # "wl-paste --watch cliphist store &"
        "hyprnotify -s" # Notification daemon using hyprctl notify
        "hyprctl setcursor catppuccin-macchiato-teal-cursors 24 &"

        # TODO: Add AGS startup here
        # "ags &"

        # NOTE: Don't start hyprlock on boot! hypridle will lock when needed
        # "hyprlock"

        # Set primary monitor (Wayland-native way)
        # "hyprctl dispatch focusmonitor DP-2"
        # Auth daemon for GUI apps requesting privilege elevation
        "systemctl --user start hyprpolkitagent"
        # which to choose?
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        # which to choose?
        "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "systemctl --user start xdg-desktop-portal-gtk"

        # "hyprsunset" # Blue light & gamma (brightness) filter # Also see for IPC through hyperctl: https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/#ipc
#hyprpm reload   # Hypr plugin manager (Mouse cursor etc.)
        #ianny					# Reminder utility for taking screen breaks
      ]
      ++ (
        if host == "amanita" then
          [
            # Application launches for amanita (workspace assignment via windowrulev2)
            "obsidian"
            "discord"
            "zen"
            "slack"
            "proton-mail"
            "keepassxc"
            # "ticktick"
            "signal-desktop"
            "spotify"
            "wezterm connect unix"
          ]
        else
          [ ]
      );

      input = {
        kb_layout = "us";
        # kb_layout = "us,de";
        # kb_variant =
        # kb_model =
        # kb_options =
        # kb_rules =

        numlock_by_default = true;
        repeat_delay = 240;
        repeat_rate = 35;

        follow_mouse = 1;
        # follow_mouse = 0; # -> true?
        # mouse_refocus = 0;
        # float_switch_override_focus = 0;

        # Desktop input settings (laptop settings are in laptop-only.nix)
        sensitivity = 1; # -1.0 - 1.0, 0 means no modification
        accel_profile = "flat"; # Flat for desktop mouse
        scroll_factor = 1.0;
        natural_scroll = false;
      };

      general = {
        gaps_in = 5;
        gaps_out = 5;
        # gaps_out = if host == "cordyceps" then [ 1 1 0 1 ] else [ 5 15 15 15 ];

        border_size = 3;
        layout = "dwindle";

        # https://wiki.hyprland.org/Configuring/Variables/#variable-types for info about colors
        # Catppuccin Macchiato: Red (#ed8796) -> Pink (#f5bde6)
        "col.active_border" = "rgba(ed8796ee) rgba(f5bde6ee) 45deg";
        "col.inactive_border" = "rgba(5b6078aa)"; # Catppuccin surface1

        # Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true;

        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
        allow_tearing = true;
      };

      #TODO: same
      misc = {
        force_default_wallpaper = 0; # Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo = true;
        disable_splash_rendering = true;

        # disable_autoreload = true;
        # always_follow_on_dnd = true;
        # layers_hog_keyboard_focus = true;
        # animate_manual_resizes = false;
        # enable_swallow = true;
        # focus_on_activate = true;
        # new_window_takes_over_fullscreen = 2;
      };

      dwindle = {
        pseudotile = true; # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        preserve_split = true;

        # no_gaps_when_only = false;
        # force_split = 0;
        # special_scale_factor = 1.0;
        # split_width_multiplier = 1.0;
        # use_active_for_splits = true;
      };

      master = {
        new_status = "master";
        mfact = 0.60;
        # workspace = $layoutopt

        # special_scale_factor = 1;
        # no_gaps_when_only = false;
      };

      decoration = {
        rounding = 10;
        rounding_power = 2;
        # Change transparency of focused and unfocused windows
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        # active_opacity = 0.90;
        # inactive_opacity = 0.90;
        # fullscreen_opacity = 1.0;

        blur = {
          enabled = true;
          passes = 1;
          # passes = 2;
          vibrancy = 0.1696;

          # size = 3;
          # brightness = 1;
          # contrast = 1.4;
          # ignore_opacity = true;
          # noise = 0;
          # new_optimizations = true;
          # xray = true;
        };

        shadow = {
          enabled = true;
          range = 4;
          # range = 20;
          render_power = 3;
          color = "rgba(1a1a1aee)";
          # offset = "0 2";
          # ignore_window = true;
        };
      };

      animations = {
        enabled = true;

        # hyprfocus plugin
        # animation = hyprfocusIn, 1, 0.8, default
        # animation = hyprfocusOut, 1, 2.7, default

        # Default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

        # Host-specific: enable workspace wraparound on amanita (desktop with multiple monitors)
        workspace_wraparound = host == "amanita";

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1.0"
          "quick,0.15,0,0.1,1"
        ];
        # maybe add later
        # "fade_curve, 0, 0.55, 0.45, 1"
        # "fluent_decel, 0, 0.2, 0.4, 1"

        # name, enable, speed, curve, style
        animation = [
          "global, 1, 10, default"
          "border, 1, 5.39, easeOutQuint"
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fade, 1, 3.03, quick"
          "layers, 1, 3.81, easeOutQuint"
          "layersIn, 1, 4, easeOutQuint, fade"
          "layersOut, 1, 1.5, linear, fade"
          "fadeLayersIn, 1, 1.79, almostLinear"
          "fadeLayersOut, 1, 1.39, almostLinear"
          "workspaces, 1, 1.94, almostLinear, fade"
          "workspacesIn, 1, 1.21, almostLinear, fade"
          "workspacesOut, 1, 1.94, almostLinear, fade"
        ];

        #
        # animation = [
        #
        #   # Windows
        #   "windowsIn,   0, 4, easeOutCubic,  popin 20%" # window open
        #   "windowsOut,  0, 4, fluent_decel,  popin 80%" # window close.
        #   "windowsMove, 1, 2, fluent_decel, slide" # everything in between, moving, dragging, resizing.
        #
        #   # Fade
        #   "fadeIn,      1, 3,   fade_curve" # fade in (open) -> layers and windows
        #   "fadeOut,     1, 3,   fade_curve" # fade out (close) -> layers and windows
        #   "fadeSwitch,  0, 1,   easeOutCirc" # fade on changing activewindow and its opacity
        #   "fadeShadow,  1, 10,  easeOutCirc" # fade on changing activewindow for shadows
        #   "fadeDim,     1, 4,   fluent_decel" # the easing of the dimming of inactive windows
        #   # "border,      1, 2.7, easeOutCirc"  # for animating the border's color switch speed
        #   # "borderangle, 1, 30,  fluent_decel, once" # for animating the border's gradient angle - styles: once (default), loop
        #   "workspaces,  1, 4,   easeOutCubic, fade" # styles: slide, slidevert, fade, slidefade, slidefadevert
        # ];
      };

      windowrule = [
        # See https://wiki.hypr.land/Configuring/Window-Rules/

        # Fix some dragging issues with XWayland
        # TODO: doesn't work, fix? -> all 3 lines
        # "nofocus on, match:class ^()$, match:title ^()$, match:xwayland true, match:floating true, match:fullscreen false, match:pinned false"

        # Ignore maximize requests from apps. TODO: Good idea?
        # "suppressevent maximize on, match:class .*"

        # CS2 tweak, https://wiki.hypr.land/Configuring/Tearing/#enabling-tearing
        # "immediate on, match:class ^(cs2)$"
        # "float on, match:class ^(Viewnior)$"
        # "float on, match:class ^(imv)$"
        # "float on, match:class ^(mpv)$"
        # "tile on, match:class ^(Aseprite)$"
        # "float on, match:class ^(audacious)$"
        # "tile on, match:class ^(neovide)$"
        # "idleinhibit focus on, match:class ^(mpv)$"
        # "float on, match:class ^(udiskie)$"
        # "float on, match:title ^(Transmission)$"
        # "float on, match:title ^(Volume Control)$"
        # "float on, match:title ^(Firefox — Sharing Indicator)$"
        # "move 0 0 on, match:title ^(Firefox — Sharing Indicator)$"
        # "size 700 450 on, match:title ^(Volume Control)$"
        # "move 40 55% on, match:title ^(Volume Control)$"

        # Wine/Proton popups (color pickers, dialogs) under XWayland have empty class and title.
        # Without this, Hyprland tiles them at 0,0 behind the main window while they hold focus,
        # causing the "invisible popup / UI unresponsive" symptom seen in Plasticity.
        "float on, match:class ^()$, match:title ^()$, match:xwayland true"
        # Plasticity material popup (XWayland child window, empty title)
        "float on, match:class ^(steam_app_0)$, match:title ^()$"
        "no_initial_focus on, match:class ^(steam_app_0)$, match:title ^()$"
        "no_follow_mouse on, match:class ^(steam_app_0)$, match:title ^()$"

        #
        # Workspace assignments for amanita
        # DP-1 (left 4K monitor): Workspaces 1-3
        "match:class ^(obsidian)$, workspace 1 silent"
        "match:class ^(discord)$, workspace 2 silent"

        # DP-2 (center 240Hz monitor): Workspaces 4-6
        "match:class ^(zen)$, workspace 4"

        # HDMI-A-2 (right vertical monitor): Workspaces 7-9
        "match:class ^(Slack)$, workspace 7 silent"
        "match:class ^(proton-mail)$, workspace 7 silent"
        "match:class ^(org.keepassxc.KeePassXC)$, workspace 7 silent"
        "match:class ^(signal)$, workspace 8 silent"
        "match:class ^(spotify)$, workspace 9 silent"
        "match:class ^(org.wezfurlong.wezterm)$, match:title ^(pulsemixer)$, workspace 9 silent"

        # Force all games to DP-2 (main 240Hz monitor)
        # Steam games
        # "match:class ^(steam_app_).*, monitor DP-2"
        # "match:class ^(steam_app_).*, workspace 5"

        # Common game engines and launchers
        # "match:class ^(gamescope).*, monitor DP-2"
        # "match:title ^(.*Unity.*)$, monitor DP-2"
        # "match:title ^(.*Unreal.*)$, monitor DP-2"

        # Enable tearing for better FPS in games
        # "match:class ^(steam_app_).*, immediate on"
        # "match:class ^(gamescope).*, immediate on"

        # Disable blur and animations for games (performance)
        # "match:class ^(steam_app_).*, noblur on"
        # "match:class ^(gamescope).*, noblur on"
        # "match:class ^(steam_app_).*, noshadow on"

        # Prevent idle when gaming
        # "match:class ^(steam_app_).*, idleinhibit focus"
        # "match:class ^(gamescope).*, idleinhibit focus"

        # Specific game rules (add your games here)
        # Example: "match:title ^(Abiotic Factor).*, monitor DP-2"
      ];
      #
      # windowrulev2 = [
      #
      #   # "float, title:^(Picture-in-Picture)$"
      #   # "opacity 1.0 override 1.0 override, title:^(Picture-in-Picture)$"
      #   # "pin, title:^(Picture-in-Picture)$"
      #   # "opacity 1.0 override 1.0 override, title:^(.*imv.*)$"
      #   # "opacity 1.0 override 1.0 override, title:^(.*mpv.*)$"
      #   # "opacity 1.0 override 1.0 override, class:(Aseprite)"
      #   # "opacity 1.0 override 1.0 override, class:(Unity)"
      #   # "opacity 1.0 override 1.0 override, class:(zen)"
      #   # "opacity 1.0 override 1.0 override, class:(evince)"
      #   # "idleinhibit focus, class:^(mpv)$"
      #   # "idleinhibit fullscreen, class:^(firefox)$"
      #   # "float,class:^(org.gnome.Calculator)$"
      #   # "float,class:^(waypaper)$"
      #   # "float,class:^(zenity)$"
      #   # "float,class:^(SoundWireServer)$"
      #   # "float,class:^(.sameboy-wrapped)$"
      #   # "float,class:^(file_progress)$"
      #   # "float,class:^(confirm)$"
      #   # "float,class:^(dialog)$"
      #   # "float,class:^(download)$"
      #   # "float,class:^(notification)$"
      #   # "float,class:^(error)$"
      #   # "float,class:^(confirmreset)$"
      #   # "float,title:^(Open File)$"
      #   # "float,title:^(File Upload)$"
      #   # "float,title:^(branchdialog)$"
      #   # "float,title:^(Confirm to replace files)$"
      #   # "float,title:^(File Operation Progress)$"
      #   #
      #   # "opacity 0.0 override,class:^(xwaylandvideobridge)$"
      #   # "noanim,class:^(xwaylandvideobridge)$"
      #   # "noinitialfocus,class:^(xwaylandvideobridge)$"
      #   # "maxsize 1 1,class:^(xwaylandvideobridge)$"
      #   # "noblur,class:^(xwaylandvideobridge)$"
      #   #
      #   # No gaps when only
      #   # "bordersize 0, floating:0, onworkspace:w[t1]"
      #   # "rounding 0, floating:0, onworkspace:w[t1]"
      #   # "bordersize 0, floating:0, onworkspace:w[tg1]"
      #   # "rounding 0, floating:0, onworkspace:w[tg1]"
      #   # "bordersize 0, floating:0, onworkspace:f[1]"
      #   # "rounding 0, floating:0, onworkspace:f[1]"
      #   #
      #   # "maxsize 1111 700, floating: 1"
      #   # "center, floating: 1"
      #
      #   # Remove context menu transparency in chromium based apps
      #   # "opaque,class:^()$,title:^()$"
      #   # "noshadow,class:^()$,title:^()$"
      #   # "noblur,class:^()$,title:^()$"
      # ];
      #
      # No gaps when only
      # workspace = [
      #   "w[t1], gapsout:0, gapsin:0"
      #   "w[tg1], gapsout:0, gapsin:0"
      #   "f[1], gapsout:0, gapsin:0"
      # ];

      debug = {
        disable_logs = false;
      };
    };

    extraConfig = "
      xwayland {
        force_zero_scaling = true
      }
    ";
  };
}
