{ host, ... }:
{
  wayland.windowManager.hyprland = {
    settings = {
      # Main modifier is set in general section of config.nix as "$mainMod" = "SUPER"

      bind = [
        # Apps
        "$mainMod, F5, exec, hyprctl reload"
        "$mainMod, T, exec, wezterm connect unix"
        "$mainMod, RETURN, exec, vicinae toggle"
        "$mainMod, R, exec, vicinae toggle"
        "$mainMod, E, exec, wezterm start --always-new-process yazi"
        "$mainMod, C, killactive,"
        # "$mainMod, M, exit,"
        "$mainMod, F, togglefloating,"
        "$mainMod, P, pseudo," # dwindle
        "$mainMod, V, layoutmsg, togglesplit" # dwindle

        # Notifications
        "$mainMod, N, exec, swaync-client -t"

        # Idle inhibit toggle (caffeine) — holds a Wayland idle inhibitor via
        # wlinhibit so hypridle won't blank/lock. Stateless toggle: pkill's exit
        # code IS the state (killed something = it was on → now off). notify-send
        # routes through swaync; the synchronous hint replaces the prior toast.
        ''$mainMod SHIFT, I, exec, pkill -x wlinhibit && notify-send -a wlinhibit -h string:x-canonical-private-synchronous:idleinhibit "Idle inhibit OFF" || (wlinhibit & notify-send -a wlinhibit -h string:x-canonical-private-synchronous:idleinhibit "Idle inhibit ON")''

        # Screenshots
        "$mainMod, S, exec, slurp | grim -g - - | wl-copy"
        "$mainMod SHIFT, S, exec, grim -g \"$(slurp)\" - | tee /tmp/screenshot.png | wl-copy && swappy -f /tmp/screenshot.png -o ~/Pictures/swappy/$(date +%F_%H-%M-%S).png"
        # Whole monitor under the cursor straight into swappy (no region select).
        # Hyprland's focus follows the mouse, so the "focused" monitor IS the one the
        # cursor is on; jq pulls its output name for grim -o.
        "CTRL ALT SHIFT, S, exec, grim -o \"$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')\" - | tee /tmp/screenshot.png | wl-copy && swappy -f /tmp/screenshot.png -o ~/Pictures/swappy/$(date +%F_%H-%M-%S).png"

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
        # Auto-correct into one column: after a cross-monitor move, focus follows the
        # window onto the target workspace, so a second bind on the same key promotes
        # it into its own full-width column instead of letting it stack side-by-side.
        # Hyprland fires all binds matching a key, in order, so move-then-promote runs
        # as one press. promote is a no-op on the dwindle monitors, so this is safe.
        "$mainMod ALT, O, layoutmsg, promote"
        "$mainMod ALT, I, layoutmsg, promote"

        # Mouse workspace navigation
        "$mainMod, mouse:275, workspace, m+1"
        "$mainMod, mouse:276, workspace, m-1"
        "$mainMod ALT, mouse:275, movetoworkspace, m+1"
        "$mainMod ALT, mouse:276, movetoworkspace, m-1"
        # Same auto-correct for the side-button (mouse:275/276) window moves.
        "$mainMod ALT, mouse:275, layoutmsg, promote"
        "$mainMod ALT, mouse:276, layoutmsg, promote"

        # Alt-Tab workspace cycling
        "ALT_L, TAB, workspace, m+1"
        "ALT_L SHIFT, TAB, workspace, m-1"

        # Special workspace (scratchpad)
        "$mainMod, SPACE, togglespecialworkspace, magic"
        "$mainMod SHIFT, SPACE, movetoworkspace, special:magic"

        # Resize window — moved to the `binde` list below so holding a key repeats.

        # Scrolling layout (workspaces 7-9) — layoutmsg is layout-scoped, so these
        # are no-ops on dwindle workspaces. mouse_up/down = scroll wheel (free: the
        # existing mouse workspace binds use the side buttons mouse:275/276).
        # NOTE: tried 'move +200/-200' (pixel pan of the tape) for a "scroll the whole
        # screen" feel — reverted: the wheel event still reaches the focused app, so it
        # panned the tape AND scrolled app content at once. 'move +col' jumps in discrete
        # column steps, which doesn't fight app scrolling the same way.
        "$mainMod, mouse_down, layoutmsg, move +col" # wheel: scroll tape toward next window
        "$mainMod, mouse_up, layoutmsg, move -col" # wheel: scroll tape toward previous window
        "$mainMod ALT, mouse_down, layoutmsg, swapcol r" # Super+Alt+wheel: move focused window down the tape
        "$mainMod ALT, mouse_up, layoutmsg, swapcol l" # Super+Alt+wheel: move focused window up the tape
        "$mainMod, comma, layoutmsg, colresize -conf" # cycle column width down
        "$mainMod, period, layoutmsg, colresize +conf" # cycle column width up
        # promote = give the active window its OWN full-width column (row) on the tape,
        # so it stops sharing a column side-by-side. Bound to home-row ';' because the
        # bracket consume/expel keys below are an awkward reach when tidying up windows
        # moved over to the vertical screen.
        "$mainMod, semicolon, layoutmsg, promote" # pop active window into its own full-width row
        # NOTE: 'fit expand' removed — on the vertical (direction:down) tape it computed a
        # negative window height and made the window vanish. Use a real fullscreen toggle instead if wanted.
        "$mainMod, bracketleft, layoutmsg, consume_or_expel prev" # merge active window into previous column
        "$mainMod, bracketright, layoutmsg, consume_or_expel next" # split active window out to next column

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

      # Resize window (binde = repeat while held). Arrows are the coarse step
      # (100px), Super+Shift+HJKL the fine step (50px). HJKL follows the same
      # h=left/j=down/k=up/l=right mapping as the movefocus/movewindow binds.
      binde = [
        "$mainMod, left, resizeactive, -100 0"
        "$mainMod, right, resizeactive, 100 0"
        "$mainMod, up, resizeactive, 0 -100"
        "$mainMod, down, resizeactive, 0 100"
        "$mainMod SHIFT, H, resizeactive, -50 0"
        "$mainMod SHIFT, L, resizeactive, 50 0"
        "$mainMod SHIFT, K, resizeactive, 0 -50"
        "$mainMod SHIFT, J, resizeactive, 0 50"
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
