{ host, lib, ... }:
{
  wayland.windowManager.hyprland = {
    settings = {
      # Lua config (Hyprland 0.56+). Section blocks all live under `config`,
      # which the home-manager module renders as hl.config({ ... }).
      config = {
        input = {
          kb_layout = "us";
          # kb_layout = "us,de";

          numlock_by_default = true;
          repeat_delay = 240;
          repeat_rate = 35;

          follow_mouse = 1;

          # Desktop input settings (laptop settings are in laptop-only.nix)
          sensitivity = 1; # -1.0 - 1.0, 0 means no modification
          accel_profile = "flat"; # Flat for desktop mouse
          scroll_factor = 1.0;
          natural_scroll = false;
        };

        general = {
          gaps_in = 10;
          gaps_out = 10;

          border_size = 3;
          layout = "dwindle";

          # Catppuccin yellow active border — matches the glow + shadow accent.
          # Nested table now; the old "col.active_border" flat key was hyprlang.
          col = {
            active_border = "rgba(f9e2afff)"; # Catppuccin yellow
            inactive_border = "rgba(5b6078aa)"; # Catppuccin surface1
          };

          # Set to true enable resizing windows by clicking and dragging on borders and gaps
          resize_on_border = true;

          # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
          allow_tearing = true;
        };

        misc = {
          force_default_wallpaper = 0; # Set to 0 or 1 to disable the anime mascot wallpapers
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
        };

        dwindle = {
          preserve_split = true;
        };

        master = {
          new_status = "master";
          mfact = 0.60;
        };

        # Scrolling layout — used on workspaces 7-9 (portrait HDMI-A-2).
        # https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
        scrolling = {
          direction = "down"; # vertical tape; new windows grow downward
          follow_focus = true; # auto-scroll the focused window into view (default)
          fullscreen_on_one_column = true; # a lone window still fills the screen
          # focus_fit_method 1 = fit: the focused column scrolls flush into view, so a
          # stack reads from the top edge downward.
          focus_fit_method = 1;

          # On the direction:down tape, column_width / explicit_column_widths are HEIGHT
          # fractions each window claims (no separate "peek" knob — the peek is leftover
          # space). explicit_column_widths is the list cycled by meta+,/meta+. (colresize
          # -conf/+conf); column_width is the size a NEW window spawns at.
          explicit_column_widths = "0.333, 0.5, 0.667, 1.0";
          column_width = 0.5;
        };

        decoration = {
          rounding = 10;
          rounding_power = 2;
          active_opacity = 1.0;
          inactive_opacity = 1.0;

          blur = {
            enabled = true;
            passes = 1;
            vibrancy = 0.1696;
          };

          shadow = {
            enabled = true;
            range = 5; # modest; well within the 10px gap
            render_power = 4; # fast falloff
            color = "rgba(f9e2afff)"; # yellow on the active window (2nd focus cue)
            color_inactive = "rgba(11111baa)"; # Catppuccin crust on inactive windows
          };

          # Inner glow on windows (reuses the shadow decoration engine)
          glow = {
            enabled = true;
            range = 8; # tight inner rim
            render_power = 3;
            color = "rgba(f9e2afff)"; # Catppuccin yellow (active window only)
            color_inactive = "rgba(f9e2af00)"; # transparent → no glow when unfocused
          };
        };

        animations = {
          enabled = true;
          # Host-specific: workspace wraparound on amanita (multi-monitor desktop)
          workspace_wraparound = host == "amanita";
        };

        # Was a raw hyprlang `xwayland { }` block in extraConfig.
        xwayland = {
          force_zero_scaling = true;
        };

        debug = {
          disable_logs = false;
        };
      };

      # Animation curves. Was `animations.bezier`; now a top-level hl.curve()
      # call taking a structured point list instead of a comma string.
      curve = [
        {
          _args = [
            "easeOutQuint"
            {
              type = "bezier";
              points = [
                [ 0.23 1 ]
                [ 0.32 1 ]
              ];
            }
          ];
        }
        {
          _args = [
            "easeInOutCubic"
            {
              type = "bezier";
              points = [
                [ 0.65 0.05 ]
                [ 0.36 1 ]
              ];
            }
          ];
        }
        {
          _args = [
            "linear"
            {
              type = "bezier";
              points = [
                [ 0 0 ]
                [ 1 1 ]
              ];
            }
          ];
        }
        {
          _args = [
            "almostLinear"
            {
              type = "bezier";
              points = [
                [ 0.5 0.5 ]
                [ 0.75 1.0 ]
              ];
            }
          ];
        }
        {
          _args = [
            "quick"
            {
              type = "bezier";
              points = [
                [ 0.15 0 ]
                [ 0.1 1 ]
              ];
            }
          ];
        }
      ];

      # Was `animations.animation` comma strings; now one table per leaf.
      animation = [
        { leaf = "global"; enabled = true; speed = 10; bezier = "default"; }
        { leaf = "border"; enabled = true; speed = 5.39; bezier = "easeOutQuint"; }
        { leaf = "windows"; enabled = true; speed = 4.79; bezier = "easeOutQuint"; }
        { leaf = "windowsIn"; enabled = true; speed = 4.1; bezier = "easeOutQuint"; style = "popin 87%"; }
        { leaf = "windowsOut"; enabled = true; speed = 1.49; bezier = "linear"; style = "popin 87%"; }
        { leaf = "fadeIn"; enabled = true; speed = 1.73; bezier = "almostLinear"; }
        { leaf = "fadeOut"; enabled = true; speed = 1.46; bezier = "almostLinear"; }
        { leaf = "fade"; enabled = true; speed = 3.03; bezier = "quick"; }
        { leaf = "layers"; enabled = true; speed = 3.81; bezier = "easeOutQuint"; }
        { leaf = "layersIn"; enabled = true; speed = 4; bezier = "easeOutQuint"; style = "fade"; }
        { leaf = "layersOut"; enabled = true; speed = 1.5; bezier = "linear"; style = "fade"; }
        { leaf = "fadeLayersIn"; enabled = true; speed = 1.79; bezier = "almostLinear"; }
        { leaf = "fadeLayersOut"; enabled = true; speed = 1.39; bezier = "almostLinear"; }
        { leaf = "workspaces"; enabled = true; speed = 1.94; bezier = "almostLinear"; style = "fade"; }
        { leaf = "workspacesIn"; enabled = true; speed = 1.21; bezier = "almostLinear"; style = "fade"; }
        { leaf = "workspacesOut"; enabled = true; speed = 1.94; bezier = "almostLinear"; style = "fade"; }
      ];

      # autostart — was `exec-once`.
      #
      # MUST be an hl.on("hyprland.start") hook, NOT a top-level hl.exec_cmd():
      # the Lua config is executed during config *parsing*, which happens before
      # the Wayland backend exists — every [executor] line lands ~40 log lines
      # before "Creating an Aquamarine backend!", so GUI apps find no Wayland
      # socket and die instantly. The hook also restores exec-once semantics;
      # a top-level exec re-fires on every `hyprctl reload`.
      on =
        let
        autostart = [
          "hyprctl setcursor catppuccin-macchiato-teal-cursors 24 &"

          # No AGS entry here on purpose: the bar runs as a systemd user unit
          # (programs.ags.systemd.enable in modules/home/ags), bound to
          # graphical-session.target, so it starts and stops with the compositor.
          # Reload after editing a widget: systemctl --user restart ags

          # NOTE: Don't start hyprlock on boot! hypridle will lock when needed

          # Set DP-2 (center 240Hz QHD) as the "main" screen: focus it at startup so
          # ad-hoc app launches land here instead of the leftmost 4K DP-1, which would
          # otherwise hold startup focus.
          "hyprctl dispatch focusmonitor DP-2"
          # Auth daemon for GUI apps requesting privilege elevation
          "vicinae server"
          "systemctl --user restart hyprpaper"
          "systemctl --user start hyprpolkitagent"
          "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "systemctl --user start xdg-desktop-portal-gtk"
        ]
        ++ (
          if host == "amanita" then
            [
              # Application launches for amanita (workspace assignment via window_rule)
              "obsidian"
              "discord"
              "zen"
              "steam"
              "proton-mail"
              "keepassxc"
              "signal-desktop"
              "spotify"
              "wezterm connect unix"
            ]
          else
            [ ]
        );
        in
        {
          _args = [
            "hyprland.start"
            (lib.generators.mkLuaInline ''
              function()
              ${lib.concatMapStrings (c: "  hl.exec_cmd(${builtins.toJSON c})\n") autostart}end
            '')
          ];
        };

      # Frost whatever sits behind the AGS bar. The namespace is set on the
      # Astal window in modules/home/ags/widget/Bar.tsx and is shared by all
      # three bars, so one rule covers every monitor.
      #
      # ignore_alpha keeps the blur from bleeding through the fully transparent
      # part of the layer surface; the bar paints its own translucent background
      # in style.scss and only that should be frosted.
      layer_rule = [
        {
          match.namespace = "^ags-bar$";
          blur = true;
        }
        {
          match.namespace = "^ags-bar$";
          ignore_alpha = 0.3;
        }
      ];

      window_rule = [
        # See https://wiki.hypr.land/Configuring/Window-Rules/

        # Prevent invisible XWayland helper windows (Steam, Wine/Proton) from stealing focus on spawn.
        # Symptom without this: clicks don't register in CS2 / sticky keys.
        # Use no_initial_focus (not no_focus): no_focus breaks interactive popups (color pickers,
        # dialogs) that share this same empty-class/title pattern — they'd float but be unclickable.
        {
          match = { class = "^$"; title = "^$"; xwayland = true; };
          no_initial_focus = true;
        }

        # CS2: enable tearing for lower input latency
        {
          match.class = "^cs2$";
          immediate = true;
        }

        # Wine/Proton popups (color pickers, dialogs) under XWayland have empty class and title.
        # Without this, Hyprland tiles them at 0,0 behind the main window while they hold focus,
        # causing the "invisible popup / UI unresponsive" symptom seen in Plasticity.
        {
          match = { class = "^$"; title = "^$"; xwayland = true; };
          float = true;
        }

        # Plasticity material popup (XWayland child window, empty title)
        {
          match = { class = "^steam_app_0$"; title = "^$"; };
          float = true;
        }
        {
          match = { class = "^steam_app_0$"; title = "^$"; };
          no_initial_focus = true;
        }
        {
          match = { class = "^steam_app_0$"; title = "^$"; };
          no_follow_mouse = true;
        }

        # Workspace assignments for amanita
        # DP-1 (left 4K monitor): Workspaces 1-3
        { match.class = "^(md\\.)?[Oo]bsidian$"; workspace = "1 silent"; }
        { match.class = "^discord$"; workspace = "2 silent"; }

        # DP-2 (center 240Hz monitor): Workspaces 4-6
        { match.class = "^zen$"; workspace = "4"; }

        # HDMI-A-2 (right vertical monitor): Workspaces 7-9
        { match.class = "^Slack$"; workspace = "7 silent"; }
        { match.class = "^proton-mail$"; workspace = "7 silent"; }
        { match.class = "^(org\\.keepassxc\\.)?KeePassXC$"; workspace = "7 silent"; }
        { match.class = "^signal$"; workspace = "8 silent"; }
        # Steam client (not games — those match ^steam_app_ below and go to DP-2)
        { match.class = "^steam$"; workspace = "8 silent"; }
        { match.class = "^[Ss]potify$"; workspace = "9 silent"; }
        {
          match = { class = "^org.wezfurlong.wezterm$"; title = "^pulsemixer$"; };
          workspace = "9 silent";
        }

        # Disable resize animation for wezterm only. Hyprland's window-resize animation
        # emits a configure event per frame; TUIs (claude, btop) repaint the whole screen
        # each frame through the mux round-trip and fall behind, causing oscillation and
        # leftover gaps while resizing. no_anim collapses the resize to a single event.
        {
          match.class = "^org.wezfurlong.wezterm$";
          no_anim = true;
        }

        # Force all games to DP-2 (main 240Hz monitor)
        # Steam games: class is steam_app_APPID (e.g. steam_app_730 for CS2)
        {
          match.class = "^steam_app_";
          monitor = "DP-2";
        }

        # Gamescope-wrapped games
        {
          match.class = "^gamescope";
          monitor = "DP-2";
        }
      ];
    };
  };
}
