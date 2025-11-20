{ pkgs, inputs, ... }:
{
  programs.wezterm = {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default; # Nightly

    extraConfig = ''
      -- Configuration
      local config = wezterm.config_builder()

      -- Window settings
      config.adjust_window_size_when_changing_font_size = false
      config.enable_scroll_bar = true
      config.scrollback_lines = 200000
      config.window_background_opacity = 0.9
      config.window_decorations = "TITLE | RESIZE"

      -- Tab bar
      config.window_close_confirmation = "NeverPrompt"
      config.hide_tab_bar_if_only_one_tab = true
      config.show_new_tab_button_in_tab_bar = false

      -- Catppuccin Macchiato theme
      config.color_scheme = "Catppuccin Macchiato"

      -- Custom keybindings
      config.keys = {
        { key = "UpArrow", mods = "SHIFT", action = wezterm.action.ScrollToPrompt(-1) },
        { key = "DownArrow", mods = "SHIFT", action = wezterm.action.ScrollToPrompt(1) },
        { key = "h", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
        { key = "l", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(1) },
        { key = "{", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
        { key = "}", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(1) },

        -- Simpler splits
        { key = "|", mods = "CTRL|SHIFT", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
        { key = "_", mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },

        -- Vim-style pane navigation
        { key = "h", mods = "ALT", action = wezterm.action.ActivatePaneDirection "Left" },
        { key = "j", mods = "ALT", action = wezterm.action.ActivatePaneDirection "Down" },
        { key = "k", mods = "ALT", action = wezterm.action.ActivatePaneDirection "Up" },
        { key = "l", mods = "ALT", action = wezterm.action.ActivatePaneDirection "Right" },
      }

      -- Tabline plugin
      local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
      tabline.setup({
        options = {
          theme = config.color_scheme or "default",
        },
        sections = {
          tabline_a = {},
          tabline_b = {},
          tabline_c = { " " },
          tabline_x = {},
          tabline_y = {},
          tabline_z = { "cpu", "ram", "battery" },
        },
      })
      tabline.apply_to_config(config)

      return config
    '';
  };
}
