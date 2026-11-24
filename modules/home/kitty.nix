{ pkgs, lib, ... }:
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

      # Only the main window counts; scratch and yazi windows have their own class
      ls=$(kitten @ ls)
      if ! jq -e 'any(.[]; .is_active and .wm_class == "kitty")' <<<"$ls" >/dev/null; then
        notify-send -a kitty "Nothing saved, only the main kitty window's tabs count"
        exit 1
      fi

      # Per tab: every foreground pid of its windows, and the active window's cwd. Not the
      # system tabs: kitty-start adds those on every start, saved they'd come back twice.
      tabs=$(jq -c '.[] | select(.is_active and .wm_class == "kitty") | .tabs[]
        | select(any(.windows[]; .user_vars.system == "1") | not)
        | {pids: [.windows[].foreground_processes[].pid],
           cwd: (first(.windows[] | select(.is_active) | .cwd) // .windows[0].cwd)}' <<<"$ls")

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

      # Only system tabs open: saving that clears the saved tabs
      tmp=$(mktemp "$out.XXXXXX")
      printf '%s' "$file" >"$tmp" && mv "$tmp" "$out"
      if [ "$count" -eq 0 ]; then
        notify-send -a kitty "Saved no tabs: kitty starts with just the system tabs"
      else
        notify-send -a kitty "Saved $count tabs ($claude claude)"
      fi
    '';
  };

  # The system tabs every kitty-start adds after the saved ones, one program each.
  # The `system` var marks them for kitty-save-tabs to skip.
  systemTabs = pkgs.writeText "system-tabs.kitty-session" (
    lib.concatMapStrings (p: ''
      new_tab ${p}
      launch --var system=1 ${p}

    '') [ "pulsemixer" "tera" "btop" "tuinews" "mirador" ]
  );

  # The one kitty window, at login and from SUPER+W when none is open:
  # the tabs ctrl+shift+s last saved, then the system tabs
  startTabs = pkgs.writeShellScriptBin "kitty-start" ''
    saved="$HOME/.local/state/kitty/default-tabs.kitty-session"
    exec ${pkgs.kitty}/bin/kitty --session - < <(
      if [ -f "$saved" ]; then cat "$saved"; fi
      printf '\n'
      cat ${systemTabs}
    )
  '';
in
{
  home.packages = [ startTabs ];

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
      # A login shell, as in WezTerm: fastfetch only runs in those
      shell = "/run/current-system/sw/bin/fish --login";

      modify_font = "cell_height 120%";
      background_opacity = "0.95";
      confirm_os_window_close = 0;
      # Selecting text copies it to the system clipboard
      copy_on_select = "clipboard";
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
      # Font size on the =/+ key: with shift bigger, without smaller; ctrl+minus stays the shell's undo
      "ctrl+plus" = "change_font_size all +1.0";
      "ctrl+shift+equal" = "change_font_size all +1.0";
      "ctrl+equal" = "change_font_size all -1.0";
      "ctrl+0" = "change_font_size all 0";
      "ctrl+alt+h" = "neighboring_window left";
      "ctrl+alt+j" = "neighboring_window down";
      "ctrl+alt+k" = "neighboring_window up";
      "ctrl+alt+l" = "neighboring_window right";
      # Same keys as WezTerm's AdjustPaneSize; the arrows shadow kitty's scroll_line_up/down
      "ctrl+shift+left" = "resize_window narrower 2";
      "ctrl+shift+right" = "resize_window wider 2";
      "ctrl+shift+up" = "resize_window shorter 2";
      "ctrl+shift+down" = "resize_window taller 2";
      "ctrl+shift+z" = "toggle_layout stack"; # zoom: the pane fills the tab
      "shift+up" = "scroll_to_prompt -1";
      "shift+down" = "scroll_to_prompt 1";
      # kitty's own keys for these were taken above
      "ctrl+shift+f" = "search_scrollback";
      "ctrl+shift+b" = "show_scrollback";
      "ctrl+shift+space" = "open_url_with_hints";
      "ctrl+shift+s" = "launch --type=background --allow-remote-control ${saveTabs}/bin/kitty-save-tabs";
    }
    # F1–F9 and alt+1–9 jump to that tab; F10–F12 still reach the program
    // builtins.listToAttrs (builtins.concatMap (n: [
      { name = "f${toString n}"; value = "goto_tab ${toString n}"; }
      { name = "alt+${toString n}"; value = "goto_tab ${toString n}"; }
    ]) [ 1 2 3 4 5 6 7 8 9 ]);

    # What a WezTerm shell passes on when kitty is started from one. Left in,
    # programs would think they run in WezTerm. The image mod loads through the
    # claude wrapper (claude.nix).
    extraConfig = ''
      env WEZTERM_PANE
      env WEZTERM_UNIX_SOCKET
      env TERM_PROGRAM
      env TERM_PROGRAM_VERSION
    '';
  };
}
