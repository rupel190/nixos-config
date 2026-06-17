{ pkgs, lib, ... }:
{
  # Laptop-specific home-manager config
  # Import this ONLY in hosts/cordyceps home config

  home.packages = with pkgs; [
    poweralertd # Battery notification daemon
    brightnessctl # Screen brightness control
  ];

  # Laptop-specific Hyprland settings
  wayland.windowManager.hyprland.settings = {
    # Touchpad-friendly mouse settings
    input = {
      sensitivity = lib.mkForce 0.2; # Higher sensitivity for touchpad
      accel_profile = lib.mkForce "adaptive"; # Better for touchpad
      touchpad = {
          scroll_factor = 0.2;
          natural_scroll = true;
        };
    };

    # 3-finger horizontal swipe to change workspaces (Hyprland 0.51+ syntax)
    gestures = {
      workspace_swipe_invert = false;
      workspace_swipe_distance = 700;
      gesture = "3, horizontal, workspace";
    };

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
}
