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
    input = {
      sensitivity = lib.mkForce 0.2; # Higher sensitivity for touchpad
      accel_profile = lib.mkForce "adaptive"; # Better for touchpad
      touchpad = {
          scroll_factor = 0.2;
          natural_scroll = true;
        };
    };

    # 3-finger horizontal swipe to change workspaces (Hyprland 0.51+ syntax).
    # NOTE: this is the touchPAD gesture engine only; touchSCREEN gestures are
    # handled by hyprgrass below.
    gestures = {
      workspace_swipe_invert = false;
      workspace_swipe_distance = 700;
      gesture = "3, horizontal, workspace";
    };

    # hyprgrass tuning. https://github.com/horriblename/hyprgrass
    plugin.touch_gestures = {
      sensitivity = 4.0;          # swipe travel multiplier
      long_press_delay = 400;     # ms before a long-press registers
      edge_margin = 10;           # px band at each edge that counts as an edge swipe
      resize_on_border_long_press = true;
    };

    # Touchscreen gesture binds. Event syntax:
    #   swipe:<fingers>:<dir>    dir letters l/r/u/d (combine e.g. lu = up-left)
    #   edge:<from_edge>:<dir>   swipe inward from a screen edge
    #   longpress:<fingers>      hold N fingers
    # `e+1/e-1` wrap around the workspace list.
    "hyprgrass-bind" = [
      ", swipe:3:l, workspace, e+1"          # 3-finger swipe left  -> next workspace
      ", swipe:3:r, workspace, e-1"          # 3-finger swipe right -> prev workspace
      ", swipe:4:u, fullscreen"              # 4-finger swipe up    -> toggle fullscreen
      ", swipe:4:d, killactive"              # 4-finger swipe down  -> close window
      ", edge:l:r, exec, vicinae toggle"     # swipe in from left edge -> launcher
    ];
    # bindm variants trigger a mouse-like drag for the gesture's duration.
    "hyprgrass-bindm" = [
      ", longpress:2, movewindow"            # 2-finger hold        -> drag window
      ", longpress:3, resizewindow"          # 3-finger hold        -> resize window
    ];

    # Brightness control keybinds
    bind = [
      ", XF86MonBrightnessUp, exec, brightnessctl s +10%"
      ", XF86MonBrightnessDown, exec, brightnessctl s 10%-"
    ];

    # Audio control keybinds (repeat when held)
    bindel = [
      ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    ];
    };
  };
}
