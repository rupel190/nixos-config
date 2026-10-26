{ pkgs, ... }:
let
  # Snapshot the main OS window as a kitty session: a claude tab resumes its
  # session by ID, any other tab becomes a shell in its cwd. Tab order is kept.
  saveTabs = pkgs.writeShellApplication {
    name = "kitty-save-tabs";
    runtimeInputs = [ pkgs.jq pkgs.kitty pkgs.libnotify pkgs.coreutils ];
    text = ''
      out="$HOME/.local/state/kitty/default-tabs.kitty-session"
      sessions="$HOME/.claude/sessions"
      mkdir -p "$(dirname "$out")"

      # Per tab: every foreground pid of its windows, and the active window's cwd.
      # Only the main window; system, scratch and yazi windows have their own class.
      tabs=$(kitten @ ls | jq -c '.[] | select(.is_active and .wm_class == "kitty") | .tabs[]
        | {pids: [.windows[].foreground_processes[].pid],
           cwd: (first(.windows[] | select(.is_active) | .cwd) // .windows[0].cwd)}')

      file="# kitty-save-tabs, $(date -Is)"$'\n'
      count=0
      claude=0
      while read -r tab; do
        [ -n "$tab" ] || continue
        entry=""
        for pid in $(jq -r '.pids[]' <<<"$tab"); do
          if [ -f "$sessions/$pid.json" ]; then
            entry=$(jq -r '"cd \(.cwd)\nlaunch claude --resume \(.sessionId)"' "$sessions/$pid.json")
            claude=$((claude + 1))
            break
          fi
        done
        [ -n "$entry" ] || entry=$(jq -r '"cd \(.cwd)\nlaunch"' <<<"$tab")
        file+=$'\n'"new_tab"$'\n'"$entry"$'\n'
        count=$((count + 1))
      done <<<"$tabs"

      if [ "$count" -eq 0 ]; then
        notify-send -a kitty "Nothing saved, only the main kitty window's tabs count"
        exit 1
      fi
      tmp=$(mktemp "$out.XXXXXX")
      printf '%s' "$file" >"$tmp" && mv "$tmp" "$out"
      notify-send -a kitty "Saved $count tabs ($claude claude)"
    '';
  };

  # Login and SUPER+W: the saved tabs, minus claude sessions still running
  # elsewhere (another kitty, wezterm), which must never be resumed twice.
  startTabs = pkgs.writeShellApplication {
    name = "kitty-start";
    runtimeInputs = [ pkgs.jq pkgs.kitty pkgs.gawk pkgs.gnugrep pkgs.coreutils ];
    text = ''
      saved="$HOME/.local/state/kitty/default-tabs.kitty-session"
      [ -f "$saved" ] || exec kitty

      # Live = the pid still has the start time claude recorded, so a pid reused after a reboot doesn't count
      live=""
      for s in "$HOME"/.claude/sessions/*.json; do
        [ -f "$s" ] || continue
        read -r pid start id < <(jq -r '"\(.pid) \(.procStart) \(.sessionId)"' "$s") || continue
        if [ "$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null)" = "$start" ]; then
          live+="$id"$'\n'
        fi
      done

      # One paragraph per tab; drop the ones whose session is live or already restored above
      session="''${XDG_RUNTIME_DIR:-/tmp}/default.kitty-session"
      awk -v live="$live" '
        BEGIN { RS = ""; ORS = "\n\n"; n = split(live, ids, "\n"); for (i = 1; i <= n; i++) if (ids[i] != "") skip[ids[i]] = 1 }
        match($0, /--resume [^ \n]+/) { id = substr($0, RSTART + 9, RLENGTH - 9); if (id in skip) next; skip[id] = 1 }
        { print }
      ' "$saved" >"$session"
      grep -q '^new_tab' "$session" || exec kitty
      exec kitty --session "$session"
    '';
  };

  # The "system" window at login: pulsemixer over tera, btop in a second tab.
  # Its class sends it to workspace 9 (hyprland/config.nix).
  systemSession = pkgs.writeText "system.kitty-session" ''
    launch pulsemixer
    launch --location=hsplit --bias=60 tera

    new_tab
    launch btop
  '';
  systemWindow = pkgs.writeShellScriptBin "kitty-system" ''
    exec ${pkgs.kitty}/bin/kitty --class kitty-system --session ${systemSession}
  '';

in
{
  home.packages = [ startTabs systemWindow ];

  # The main terminal: stock kitty plus the looks and keys below.
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Macchiato";
    font = {
      # Monaspace Xenon, light, with its ligatures and stylistic sets
      name = ''family="MonaspiceXe Nerd Font Mono" style=Light features="+calt +ss01 +ss02 +ss03 +ss04 +ss06 +ss09 +ss10"'';
      size = 12;
    };

    settings = {
      modify_font = "cell_height 120%";
      background_opacity = "0.95";
      confirm_os_window_close = 0;
      # Hyprland reports a filled tile as maximized; remembered, every new kitty opened maximized over the others
      remember_window_size = "no";

      # Vertical tabs; long titles wrap onto a second line instead of truncating
      tab_bar_edge = "left";
      tab_bar_min_tabs = 1;
      tab_title_max_lines = 2;
      tab_title_wrap = "yes";

      enabled_layouts = "splits,stack";

      # `kitten @` through a socket only, never escape codes; kitty appends -<pid>
      allow_remote_control = "socket-only";
      listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty";
    };

    # ctrl+shift for tabs, splits and the scrollback; ctrl+alt to move between panes
    keybindings = {
      # Tabs run top to bottom here, so j/k; h/l pass through to the program
      "ctrl+shift+k" = "previous_tab";
      "ctrl+shift+j" = "next_tab";
      "ctrl+shift+h" = "no_op";
      "ctrl+shift+l" = "no_op";
      "ctrl+shift+[" = "move_tab_backward";
      "ctrl+shift+]" = "move_tab_forward";
      "ctrl+shift+t" = "new_tab_with_cwd";
      "ctrl+shift+w" = "close_tab";
      "ctrl+shift+q" = "close_window"; # this pane only
      "ctrl+shift+e" = "set_tab_title";
      "ctrl+shift+\\" = "launch --location=vsplit --cwd=current";
      "ctrl+shift+minus" = "launch --location=hsplit --cwd=current";
      "ctrl+alt+h" = "neighboring_window left";
      "ctrl+alt+j" = "neighboring_window down";
      "ctrl+alt+k" = "neighboring_window up";
      "ctrl+alt+l" = "neighboring_window right";
      "ctrl+shift+z" = "toggle_layout stack"; # zoom: the pane fills the tab
      "shift+up" = "scroll_to_prompt -1";
      "shift+down" = "scroll_to_prompt 1";
      # kitty's own keys for these were taken above
      "ctrl+shift+f" = "search_scrollback";
      "ctrl+shift+b" = "show_scrollback";
      "ctrl+shift+space" = "open_url_with_hints";
      "ctrl+shift+s" = "launch --type=background --allow-remote-control ${saveTabs}/bin/kitty-save-tabs";
    };

    # What a WezTerm shell passes on when kitty is started from one. Left in,
    # claude's tab hook would paint a WezTerm tab and programs would think they
    # run in WezTerm.
    extraConfig = ''
      env WEZTERM_PANE
      env WEZTERM_UNIX_SOCKET
      env TERM_PROGRAM
      env TERM_PROGRAM_VERSION
    '';
  };
}
