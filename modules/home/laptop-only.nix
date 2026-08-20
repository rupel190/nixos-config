{ inputs, pkgs, lib, ... }:
{
  # Laptop-specific home-manager config
  # Import this ONLY in hosts/cordyceps home config

  home.packages = with pkgs; [
    poweralertd # Battery notification daemon
    brightnessctl # Screen brightness control
  ];

  # Laptop-specific Hyprland settings
  wayland.windowManager.hyprland = {
    # hyprgrass: touchscreen gestures for the FW13 touch panel. Hyprland's
    # built-in `gesture` engine only fires on the touchpad, not the touch
    # digitizer — hyprgrass reads the touch device directly. Pinned to follow
    # our git Hyprland (see flake input) so the plugin ABI matches.
    plugins = [
      inputs.hyprgrass.packages.${pkgs.stdenv.hostPlatform.system}.hyprgrass
    ];

    settings = {
      # Touchpad-friendly mouse settings
      config.input = {
        sensitivity = lib.mkForce 0.2; # Higher sensitivity for touchpad
        accel_profile = lib.mkForce "adaptive"; # Better for touchpad
        touchpad = {
          scroll_factor = 0.2;
          natural_scroll = true;
        };
      };

      # NOTE: this is the touchPAD gesture engine only; touchSCREEN gestures are
      # handled by hyprgrass (see the disabled block below).
      config.gestures = {
        workspace_swipe_invert = false;
        workspace_swipe_distance = 700;
      };

      # 3-finger horizontal swipe to change workspaces. Was the
      # `gestures.gesture = "3, horizontal, workspace"` string.
      gesture = {
        fingers = 3;
        direction = "horizontal";
        action = "workspace";
      };

      # Brightness control keybinds
      bind = [
        {
          _args = [
            "XF86MonBrightnessUp"
            (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("brightnessctl s +10%")'')
          ];
        }
        {
          _args = [
            "XF86MonBrightnessDown"
            (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("brightnessctl s 10%-")'')
          ];
        }
        # Audio control (repeat when held, work while locked)
        {
          _args = [
            "XF86AudioRaiseVolume"
            (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")'')
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86AudioLowerVolume"
            (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")'')
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86AudioMute"
            (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")'')
            {
              locked = true;
              repeating = true;
            }
          ];
        }
      ];

      # DISABLED IN THE 0.56 LUA MIGRATION — touchscreen gestures are off on this
      # host until the plugin side is verified.
      #
      # `plugin.touch_gestures`, `hyprgrass-bind` and `hyprgrass-bindm` are
      # hyprlang-only constructs: the Lua emitter would render them as
      # `hl.hyprgrass-bind(...)`, which is not even valid Lua. hyprgrass has to
      # expose a Lua API (hl.plugin.*) before these can come back, and that could
      # not be verified from amanita. Re-enable once checked ON the laptop.
      #
      # plugin.touch_gestures = {
      #   sensitivity = 4.0;          # swipe travel multiplier
      #   long_press_delay = 400;     # ms before a long-press registers
      #   edge_margin = 10;           # px band at each edge that counts as an edge swipe
      #   resize_on_border_long_press = true;
      # };
      # "hyprgrass-bind" = [
      #   ", swipe:3:l, workspace, e+1"          # 3-finger swipe left  -> next workspace
      #   ", swipe:3:r, workspace, e-1"          # 3-finger swipe right -> prev workspace
      #   ", swipe:4:u, fullscreen"              # 4-finger swipe up    -> toggle fullscreen
      #   ", swipe:4:d, killactive"              # 4-finger swipe down  -> close window
      #   ", edge:l:r, exec, vicinae toggle"     # swipe in from left edge -> launcher
      # ];
      # "hyprgrass-bindm" = [
      #   ", longpress:2, movewindow"            # 2-finger hold        -> drag window
      #   ", longpress:3, resizewindow"          # 3-finger hold        -> resize window
      # ];
    };
  };
}
