{ ... }:
{
  # Trial beside wezterm: stock kitty plus the looks and the keys muscle memory expects.
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Macchiato";
    font = {
      # Same face and stylistic sets as wezterm.nix
      name = ''family="MonaspiceXe Nerd Font Mono" style=Light features="+calt +ss01 +ss02 +ss03 +ss04 +ss06 +ss09 +ss10"'';
      size = 12; # wezterm's default
    };

    settings = {
      modify_font = "cell_height 120%";
      background_opacity = "0.95";
      confirm_os_window_close = 0;

      # Vertical tabs; long titles wrap onto a second line instead of truncating
      tab_bar_edge = "left";
      tab_bar_min_tabs = 1;
      tab_title_max_lines = 2;
      tab_title_wrap = "yes";

      enabled_layouts = "splits,stack";
    };

    # wezterm.nix bindings, so switching between the two costs nothing
    keybindings = {
      "ctrl+shift+h" = "previous_tab";
      "ctrl+shift+l" = "next_tab";
      "ctrl+shift+[" = "move_tab_backward";
      "ctrl+shift+]" = "move_tab_forward";
      "ctrl+shift+t" = "new_tab_with_cwd";
      "ctrl+shift+w" = "close_tab";
      "ctrl+shift+e" = "set_tab_title";
      "ctrl+shift+\\" = "launch --location=vsplit --cwd=current";
      "ctrl+shift+minus" = "launch --location=hsplit --cwd=current";
      "ctrl+alt+h" = "neighboring_window left";
      "ctrl+alt+j" = "neighboring_window down";
      "ctrl+alt+k" = "neighboring_window up";
      "ctrl+alt+l" = "neighboring_window right";
      "ctrl+shift+z" = "toggle_layout stack"; # zoom, wezterm's default key
      "shift+up" = "scroll_to_prompt -1";
      "shift+down" = "scroll_to_prompt 1";
      # kitty's own keys for these were taken above
      "ctrl+shift+f" = "search_scrollback"; # wezterm's find key
      "ctrl+shift+b" = "show_scrollback";
      "ctrl+shift+space" = "open_url_with_hints"; # wezterm's quick-select key
    };

    # Started from a wezterm shell, these leak in and claude's status hook would
    # paint a wezterm tab for a kitty session.
    extraConfig = ''
      env WEZTERM_PANE
      env WEZTERM_UNIX_SOCKET
      env TERM_PROGRAM
      env TERM_PROGRAM_VERSION
    '';
  };
}
