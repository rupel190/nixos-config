{ pkgs, inputs, ... }:
{
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm; # Stable from nixpkgs (better OpenGL integration)
    # package = inputs.wezterm.packages.${pkgs.system}.default; # Nightly (has OpenGL issues)

    extraConfig = # lua
      ''
        -- Configuration
        local config = wezterm.config_builder()
        local mux = wezterm.mux


        -- Define workspaces
        wezterm.on('gui-startup', function(cmd)
          -- autostart
          local tab, startup_pane, window = mux.spawn_window {
            workspace = 'autostart',
            args = { 'pulsemixer' },
          }
          startup_pane:split {
            args = { 'btop' },
            direction = 'Bottom',
            size = 0.7,
          }

          local tab, remote_pane, window = mux.spawn_window {
            workspace = 'recustomize',
            args = { 'ssh', 'trichoderma' },
            cwd = '/home/rupel/projects/recustomize',
          }
          local bottom_pane = remote_pane:split {
            direction = 'Bottom',
            size = 0.2,
          }
          bottom_pane:split {
            direction = 'Right',
            size = 0.5,
          }

          local tab, beamng_pane, window = mux.spawn_window {
            workspace = 'beamng',
            args = { 'yazi' },
            cwd = '/home/rupel/.local/share/Steam/steamapps/common/BeamNG.drive',
          }
          beamng_pane:split {
            direction = 'Bottom',
            size = 0.25,
          }
          beamng_pane:split {
            direction = 'Left',
            args = { 'claude' },
            size = 0.5,
          }
          

          mux.set_active_workspace 'autostart'
        end)


        -- Window settings
        config.adjust_window_size_when_changing_font_size = false
        config.enable_scroll_bar = true
        config.scrollback_lines = 200000
        config.window_background_opacity = 0.9
        config.enable_wayland = true -- Force native Wayland (not XWayland)
        -- Note: window_decorations set after tabline.apply_to_config() at bottom

        -- Tab bar
        config.window_close_confirmation = "NeverPrompt"
        config.hide_tab_bar_if_only_one_tab = false
        config.show_new_tab_button_in_tab_bar = false

        -- Catppuccin Macchiato theme
        config.color_scheme = "Catppuccin Macchiato"

        -- Custom keybindings
        config.keys = {
          { key = "UpArrow", mods = "SHIFT", action = wezterm.action.ScrollToPrompt(-1) },
          { key = "DownArrow", mods = "SHIFT", action = wezterm.action.ScrollToPrompt(1) },
          -- Scroll with Ctrl+Alt (frees up PageUp/PageDown for nvim)
          { key = "PageUp", mods = "CTRL|ALT", action = wezterm.action.ScrollByPage(-0.9) },
          { key = "PageDown", mods = "CTRL|ALT", action = wezterm.action.ScrollByPage(0.9) },
          { key = "h", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
          { key = "l", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(1) },
          { key = "{", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
          { key = "}", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(1) },
          -- Disable close tab confirmation
          { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab { confirm = false } },

          -- Simpler splits
          { key = "|", mods = "CTRL|SHIFT", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
          { key = "_", mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },

          -- Vim-style pane navigation (Ctrl+Alt to avoid conflicts with nvim)
          { key = "h", mods = "CTRL|ALT", action = wezterm.action.ActivatePaneDirection "Left" },
          { key = "j", mods = "CTRL|ALT", action = wezterm.action.ActivatePaneDirection "Down" },
          { key = "k", mods = "CTRL|ALT", action = wezterm.action.ActivatePaneDirection "Up" },
          { key = "l", mods = "CTRL|ALT", action = wezterm.action.ActivatePaneDirection "Right" },
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
            tabline_z = { "cpu", "ram", { "datetime", style = "%Y-%m-%d %H:%M" }, "battery" },
          },
        })
        tabline.apply_to_config(config)

        -- Override tabline's decoration settings (must be AFTER apply_to_config)
        config.window_decorations = "NONE"
        config.integrated_title_buttons = {}

        return config
      '';
  };
}
