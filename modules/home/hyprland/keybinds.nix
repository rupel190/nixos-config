{ lib, host, ... }:
let
  inherit (lib.generators) mkLuaInline;

  mod = "SUPER";
  # Deep-system actions (inhibit / lock / blank) share CTRL+SUPER+ALT so they are
  # awkward enough to never fire by accident. Nothing else uses that modmask.
  sysMod = "CTRL + ${mod} + ALT";

  # Lua config (Hyprland 0.56+): a bind is hl.bind(key, dispatcher, flags?).
  # The dispatcher is a real Lua call, not the old "exec, foo" comma string, so
  # it has to be emitted inline. toJSON does the Lua string quoting for us —
  # several of these commands contain embedded double quotes.
  exec = cmd: mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON cmd})";
  dsp = expr: mkLuaInline expr;

  bind = key: action: {
    _args = [
      key
      action
    ];
  };
  bindWith = key: action: flags: {
    _args = [
      key
      action
      flags
    ];
  };

  # Old bind flag lists map onto per-bind option tables.
  repeating = {
    repeating = true;
  }; # was binde
  lockedRepeat = {
    locked = true;
    repeating = true;
  }; # was bindel
  mouse = {
    mouse = true;
  }; # was bindm

  focusDir = d: dsp ''hl.dsp.focus({ direction = "${d}" })'';
  moveDir = d: dsp ''hl.dsp.window.move({ direction = "${d}" })'';
  toWorkspace = ws: dsp ''hl.dsp.focus({ workspace = "${ws}" })'';
  moveToWorkspace = ws: dsp ''hl.dsp.window.move({ workspace = "${ws}" })'';
  # layoutmsg is layout-scoped and the Lua API now toasts a runtime error when the
  # active layout doesn't know the message, so gate every one by layout name.
  layoutmsgIn =
    layout: msg:
    dsp ''
      function()
        local ws = hl.get_active_workspace()
        if ws and ws.tiled_layout == "${layout}" then hl.dispatch(hl.dsp.layout("${msg}")) end
      end'';
  resizeActive =
    x: y: dsp "hl.dsp.window.resize({ x = ${toString x}, y = ${toString y}, relative = true })";

  # Blank outputs; null = all of them. dpms wants its target as a table field —
  # a positional dpms("off", "DP-2") is accepted silently and blanks everything.
  # The 400ms delay lets this chord's own key events land first, otherwise
  # key_press_enables_dpms lights the screens straight back up.
  dpmsOff =
    monitor:
    let
      target = lib.optionalString (monitor != null) ", monitor = \"${monitor}\"";
    in
    dsp ''
      function()
        hl.timer(function() hl.dispatch(hl.dsp.dpms({ state = "off"${target} })) end,
                 { timeout = 400, type = "oneshot" })
      end'';

  digits = [
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
  ];
in
{
  wayland.windowManager.hyprland = {
    settings = {
      bind = [
        # Apps
        (bind "${mod} + F5" (exec "hyprctl reload"))
        # Reattach to the mux. A second `connect unix` client would just mirror the
        # one mux window, so focus the existing terminal instead of spawning another.
        (bind "${mod} + W" (dsp ''
          function()
            local ws = hl.get_windows()
            for i = 1, #ws do
              if ws[i].class == "org.wezfurlong.wezterm" then
                hl.dispatch(hl.dsp.focus({ window = ws[i] }))
                return
              end
            end
            hl.dispatch(hl.dsp.exec_cmd("wezterm connect unix"))
          end''))
        # Throwaway terminal. Not `connect unix`: a second client attaches to the
        # same workspace and mirrors, and a unique --workspace leaks a shell that
        # outlives the window in the mux server. Own process = closes for good.
        # Distinct app_id so the SUPER+T reattach never grabs a scratch window.
        (bind "${mod} + T" (
          exec "wezterm start --always-new-process --class org.wezfurlong.wezterm.scratch"
        ))
        (bind "${mod} + RETURN" (exec "vicinae toggle"))
        (bind "${mod} + R" (exec "vicinae toggle"))
        (bind "${mod} + E" (
          exec "wezterm start --always-new-process --class org.wezfurlong.wezterm.yazi yazi"
        ))
        (bind "${mod} + C" (dsp "hl.dsp.window.close()"))
        (bind "${mod} + F" (dsp ''hl.dsp.window.float({ action = "toggle" })''))
        (bind "${mod} + P" (dsp "hl.dsp.window.pseudo()")) # dwindle
        (bind "${mod} + V" (layoutmsgIn "dwindle" "togglesplit"))

        # Notifications
        (bind "${mod} + N" (exec "swaync-client -t"))

        # Idle inhibit toggle (caffeine) — holds a Wayland idle inhibitor via
        # wlinhibit so hypridle won't blank/lock. Stateless toggle: pkill's exit
        # code IS the state (killed something = it was on → now off). if/else,
        # not && ||: a failing notify would otherwise relaunch what pkill just
        # killed. Feedback is hyprctl notify (drawn by Hyprland, so it survives
        # swaync's do-not-disturb) — notify-send toasts were silently dropped.
        (bind "${sysMod} + I" (
          exec ''if pkill -x wlinhibit; then hyprctl notify -1 2000 "rgb(9399b2)" "Idle inhibit OFF"; else wlinhibit & hyprctl notify -1 2000 "rgb(f9e2af)" "Idle inhibit ON"; fi''
        ))

        # Lock now. Goes through loginctl (not hyprlock directly) so hypridle's
        # lock_cmd applies — that carries the `pidof hyprlock` single-instance
        # guard and --grace 0.
        (bind "${sysMod} + L" (exec "loginctl lock-session"))

        # All monitors off.
        (bind "${sysMod} + M" (dpmsOff null))

        # Read the clipboard aloud (read-along aid for dense prose). Spelled out
        # rather than bare "say-clip" because ~/.local/bin is on PATH for
        # interactive shells, not for Hyprland's exec.
        (bind "${mod} + SHIFT + R" (exec "~/.local/bin/say-clip"))

        # Screenshots
        (bind "${mod} + S" (exec "slurp | grim -g - - | wl-copy"))
        (bind "${mod} + SHIFT + S" (
          exec ''grim -g "$(slurp)" - | tee /tmp/screenshot.png | wl-copy && swappy -f /tmp/screenshot.png -o ~/Pictures/swappy/$(date +%F_%H-%M-%S).png''
        ))
        # Whole monitor under the cursor straight into swappy (no region select).
        # Hyprland's focus follows the mouse, so the "focused" monitor IS the one the
        # cursor is on; jq pulls its output name for grim -o.
        (bind "CTRL + ALT + SHIFT + S" (
          exec ''grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" - | tee /tmp/screenshot.png | wl-copy && swappy -f /tmp/screenshot.png -o ~/Pictures/swappy/$(date +%F_%H-%M-%S).png''
        ))

        # Screen recording (portal picker: choose monitor/window/region)
        (bind "${mod} + ALT + S" (
          exec "gpu-screen-recorder -w portal -a default_output -f 60 -o ~/Videos/screenrec/$(date +%F_%H-%M-%S).mp4"
        ))
        (bind "${mod} + ALT + SHIFT + S" (
          exec ''pkill -SIGINT -f gpu-screen-recorder && hyprctl notify 1 2000 "rgb(a6da95)" "Recording saved to ~/Videos/screenrec/"''
        ))

        # Move focus
        (bind "${mod} + J" (focusDir "down"))
        (bind "${mod} + K" (focusDir "up"))
        (bind "${mod} + H" (focusDir "left"))
        (bind "${mod} + L" (focusDir "right"))

        # Move window
        (bind "${mod} + ALT + J" (moveDir "down"))
        (bind "${mod} + ALT + K" (moveDir "up"))
        (bind "${mod} + ALT + H" (moveDir "left"))
        (bind "${mod} + ALT + L" (moveDir "right"))

        # Cycle workspaces
        (bind "${mod} + O" (toWorkspace "m-1"))
        (bind "${mod} + I" (toWorkspace "m+1"))
        (bind "${mod} + ALT + O" (moveToWorkspace "m-1"))
        (bind "${mod} + ALT + I" (moveToWorkspace "m+1"))
        # Auto-correct into one column: after a cross-monitor move, focus follows the
        # window onto the target workspace, so a second bind on the same key promotes
        # it into its own full-width column instead of letting it stack side-by-side.
        # Hyprland fires all binds matching a key, in order, so move-then-promote runs
        # as one press. The guard skips promote when the destination is dwindle.
        (bind "${mod} + ALT + O" (layoutmsgIn "scrolling" "promote"))
        (bind "${mod} + ALT + I" (layoutmsgIn "scrolling" "promote"))

        # Mouse workspace navigation
        (bind "${mod} + mouse:275" (toWorkspace "m+1"))
        (bind "${mod} + mouse:276" (toWorkspace "m-1"))
        (bind "${mod} + ALT + mouse:275" (moveToWorkspace "m+1"))
        (bind "${mod} + ALT + mouse:276" (moveToWorkspace "m-1"))
        # Same auto-correct for the side-button window moves.
        (bind "${mod} + ALT + mouse:275" (layoutmsgIn "scrolling" "promote"))
        (bind "${mod} + ALT + mouse:276" (layoutmsgIn "scrolling" "promote"))

        # Special workspace (scratchpad)
        (bind "${mod} + SPACE" (dsp ''hl.dsp.workspace.toggle_special("magic")''))
        (bind "${mod} + SHIFT + SPACE" (moveToWorkspace "special:magic"))

        # Scrolling layout (workspaces 7-9). mouse_up/down = scroll wheel (free: the
        # existing mouse workspace binds use the side buttons mouse:275/276).
        # NOTE: tried 'move +200/-200' (pixel pan of the tape) — reverted: the wheel
        # event still reaches the focused app, so it panned the tape AND scrolled app
        # content at once. 'move +col' jumps in discrete column steps instead.
        (bind "${mod} + mouse_down" (layoutmsgIn "scrolling" "move +col")) # wheel: scroll tape toward next window
        (bind "${mod} + mouse_up" (layoutmsgIn "scrolling" "move -col")) # wheel: scroll tape toward previous window
        (bind "${mod} + ALT + mouse_down" (layoutmsgIn "scrolling" "swapcol r")) # move focused window down the tape
        (bind "${mod} + ALT + mouse_up" (layoutmsgIn "scrolling" "swapcol l")) # move focused window up the tape
        (bind "${mod} + comma" (layoutmsgIn "scrolling" "colresize -conf")) # cycle column width down
        (bind "${mod} + period" (layoutmsgIn "scrolling" "colresize +conf")) # cycle column width up
        # promote = give the active window its OWN full-width column (row) on the tape.
        # Bound to home-row ';' because the bracket consume/expel keys below are an
        # awkward reach when tidying up windows moved over to the vertical screen.
        (bind "${mod} + semicolon" (layoutmsgIn "scrolling" "promote"))
        # NOTE: 'fit expand' removed — on the vertical (direction:down) tape it computed a
        # negative window height and made the window vanish.
        (bind "${mod} + bracketleft" (layoutmsgIn "scrolling" "consume_or_expel prev")) # merge into previous column
        (bind "${mod} + bracketright" (layoutmsgIn "scrolling" "consume_or_expel next")) # split out to next column
      ]

      # Blank one screen at a time, left to right: 1 = DP-1, 2 = DP-2 (OLED),
      # 3 = HDMI-A-2. Panel names are amanita's, hence the host gate.
      ++ lib.optionals (host == "amanita") [
        (bind "${sysMod} + 1" (dpmsOff "DP-1"))
        (bind "${sysMod} + 2" (dpmsOff "DP-2"))
        (bind "${sysMod} + 3" (dpmsOff "HDMI-A-2"))
      ]
      # Switch workspaces with mainMod + [0-9]; move with mainMod + ALT + [0-9].
      # 0 maps to workspace 10.
      ++ (map (d: bind "${mod} + ${d}" (toWorkspace d)) digits)
      ++ [ (bind "${mod} + 0" (toWorkspace "10")) ]
      ++ (map (d: bind "${mod} + ALT + ${d}" (moveToWorkspace d)) digits)
      ++ [ (bind "${mod} + ALT + 0" (moveToWorkspace "10")) ]

      # Resize window (repeat while held). Arrows are the coarse step (100px),
      # Super+Shift+HJKL the fine step (50px). HJKL follows the same
      # h=left/j=down/k=up/l=right mapping as the movefocus/movewindow binds.
      ++ [
        (bindWith "${mod} + left" (resizeActive (-100) 0) repeating)
        (bindWith "${mod} + right" (resizeActive 100 0) repeating)
        (bindWith "${mod} + up" (resizeActive 0 (-100)) repeating)
        (bindWith "${mod} + down" (resizeActive 0 100) repeating)
        (bindWith "${mod} + SHIFT + H" (resizeActive (-50) 0) repeating)
        (bindWith "${mod} + SHIFT + L" (resizeActive 50 0) repeating)
        (bindWith "${mod} + SHIFT + K" (resizeActive 0 (-50)) repeating)
        (bindWith "${mod} + SHIFT + J" (resizeActive 0 50) repeating)
      ]

      # Audio control (repeat when held, and work while locked).
      # Note: laptop-specific keybinds (brightness) are in laptop-only.nix
      ++ [
        (bindWith "XF86AudioRaiseVolume" (exec "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+")
          lockedRepeat
        )
        (bindWith "XF86AudioLowerVolume" (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-") lockedRepeat)
        (bindWith "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") lockedRepeat)
      ]

      # Alt-Tab workspace cycling. Not on amanita: Hyprland grabs ALT globally,
      # so CS2 never sees the key and behaves as if Alt is stuck.
      ++ lib.optionals (host != "amanita") [
        (bind "ALT_L + TAB" (toWorkspace "m+1"))
        (bind "ALT_L + SHIFT + TAB" (toWorkspace "m-1"))
      ]

      # Mouse bindings
      ++ [
        (bindWith "${mod} + mouse:272" (dsp "hl.dsp.window.drag()") mouse)
        (bindWith "${mod} + mouse:273" (dsp "hl.dsp.window.resize()") mouse)
      ];
    };
  };
}
