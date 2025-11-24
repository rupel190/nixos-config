{ pkgs, ... }:
{
  # Laptop-specific home-manager config
  # Import this ONLY in hosts/cordyceps home config

  home.packages = with pkgs; [
    poweralertd # Battery notification daemon
    brightnessctl # Screen brightness control
  ];

  # Laptop-specific Hyprland settings
  wayland.windowManager.hyprland.settings = {
    # Touchpad-friendly input settings
    input = {
      sensitivity = 0.2; # Higher sensitivity for touchpad
      accel_profile = "adaptive"; # Better for touchpad
      scroll_factor = 0.2; # Slower scroll for touchpad
      natural_scroll = true; # Natural scrolling for touchpad
    };

    # Touchpad gestures (when gesture syntax is fixed in newer Hyprland)
    # gestures = {
    #   workspace_swipe = true;
    #   workspace_swipe_fingers = 3;
    # };

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
