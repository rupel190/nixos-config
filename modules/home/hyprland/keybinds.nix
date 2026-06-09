{ host, ... }:
{
  wayland.windowManager.hyprland = {
    settings = {
      # Main modifier is set in general section of config.nix as "$mainMod" = "SUPER"

      bind = [
        # Apps
        "$mainMod, F5, exec, hyprctl reload"
        "$mainMod, T, exec, wezterm connect unix"
        "$mainMod, backslash, exec, vicinae toggle"
        "$mainMod, D, exec, vicinae toggle"
        "$mainMod, RETURN, exec, fuzzel"
        "$mainMod, R, exec, fuzzel"
        "$mainMod, E, exec, wezterm start --always-new-process yazi"
        "$mainMod, C, killactive,"
        # "$mainMod, M, exit,"
        "$mainMod, F, togglefloating,"
        "$mainMod, P, pseudo," # dwindle
        "$mainMod, V, layoutmsg, togglesplit" # dwindle

        # Notifications
        "$mainMod, N, exec, swaync-client -t"

        # Screenshots
        "$mainMod, S, exec, slurp | grim -g - - | wl-copy"
        "$mainMod SHIFT, S, exec, grim -g \"$(slurp)\" - | tee /tmp/screenshot.png | wl-copy && swappy -f /tmp/screenshot.png -o ~/Pictures/swappy/$(date +%F_%H-%M-%S).png"

        # Screen recording (portal picker: choose monitor/window/region like Discord screenshare)
        "$mainMod ALT, S, exec, gpu-screen-recorder -w portal -a default_output -f 60 -o ~/Videos/screenrec/$(date +%F_%H-%M-%S).mp4"
        "$mainMod ALT SHIFT, S, exec, pkill -SIGINT -f gpu-screen-recorder && hyprctl notify 1 2000 \"rgb(a6da95)\" \"Recording saved to ~/Videos/screenrec/\""

        # Move focus
        "$mainMod, J, movefocus, d"
        "$mainMod, K, movefocus, u"
        "$mainMod, H, movefocus, l"
        "$mainMod, L, movefocus, r"

        # Move window
        "$mainMod ALT, J, movewindow, d"
        "$mainMod ALT, K, movewindow, u"
        "$mainMod ALT, H, movewindow, l"
        "$mainMod ALT, L, movewindow, r"

        # Cycle workspaces
        "$mainMod, O, workspace, m-1"
        "$mainMod, I, workspace, m+1"
        "$mainMod ALT, O, movetoworkspace, m-1"
        "$mainMod ALT, I, movetoworkspace, m+1"

        # Mouse workspace navigation
        "$mainMod, mouse:275, workspace, m+1"
        "$mainMod, mouse:276, workspace, m-1"
        "$mainMod ALT, mouse:275, movetoworkspace, m+1"
        "$mainMod ALT, mouse:276, movetoworkspace, m-1"

        # Alt-Tab workspace cycling
        "ALT_L, TAB, workspace, m+1"
        "ALT_L SHIFT, TAB, workspace, m-1"

        # Special workspace (scratchpad)
        "$mainMod, SPACE, togglespecialworkspace, magic"
        "$mainMod SHIFT, SPACE, movetoworkspace, special:magic"

        # Resize window
        "$mainMod, left, resizeactive, -50 0"
        "$mainMod, right, resizeactive, 50 0"
        "$mainMod, up, resizeactive, 0 -50"
        "$mainMod, down, resizeactive, 0 50"

        # Buffer submap (prefix key) - DISABLED for now, causing number key conflicts
        # "$mainMod, B, submap, buffer"
      ]
      ++ [
        # Submap buffer - commented out to fix number key issue
        # When enabled, this allows Super+B then number to switch workspace
        # But the syntax was causing ALL number keys to switch workspaces
        # TODO: Fix submap syntax properly if you want this feature
      ]
      ++ [
        # Switch workspaces with mainMod + [0-9]
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move active window to a workspace with mainMod + ALT + [0-9]
        "$mainMod ALT, 1, movetoworkspace, 1"
        "$mainMod ALT, 2, movetoworkspace, 2"
        "$mainMod ALT, 3, movetoworkspace, 3"
        "$mainMod ALT, 4, movetoworkspace, 4"
        "$mainMod ALT, 5, movetoworkspace, 5"
        "$mainMod ALT, 6, movetoworkspace, 6"
        "$mainMod ALT, 7, movetoworkspace, 7"
        "$mainMod ALT, 8, movetoworkspace, 8"
        "$mainMod ALT, 9, movetoworkspace, 9"
        "$mainMod ALT, 0, movetoworkspace, 10"
      ];

      # Note: Laptop-specific keybinds (brightness, audio) are in laptop-only.nix

      # Audio control keybinds (repeat when held)
      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ];

      # Mouse bindings
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };
  };
}
