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


         -- Unix domain for mux server/client architecture
         -- Allows GUI windows to be closed independently while workspaces persist
         config.unix_domains = { { name = "unix" } }
         config.default_gui_startup_args = { "connect", "unix" }

         -- Define workspaces (runs on the mux server, not the GUI client)
         wezterm.on('mux-startup', function()
           local tab, default_pane, window = mux.spawn_window {
             workspace = 'default',
           }

           local tab, pulsemixer_pane, window = mux.spawn_window {
             workspace = 'system',
             args = { 'pulsemixer' },
           }
           window:spawn_tab {
             args = { 'btop' },
           }

           local tab, remote_pane, window = mux.spawn_window {
             workspace = 'recustomize',
             args = { 'ssh', 'trichoderma' },
             cwd = '/home/rupel/projects/recustomize',
           }
           local bottom_pane = remote_pane:split {
             direction = 'Bottom',
             size = { Cells = 2 },
           }
           bottom_pane:split {
             direction = 'Right',
             size = 0.5,
           }
           window:spawn_tab {
             cwd = '/home/rupel/projects/recustomize',
           }

           local tab, remote_pane, window = mux.spawn_window {
             workspace = 'riedercc',
             cwd = '/home/rupel/projects/rieder/rieder-site/ui',
           }
           local bottom_pane = remote_pane:split {
             direction = 'Bottom',
             size = { Cells = 2 },
           }
           bottom_pane:split {
             direction = 'Right',
             size = 0.5,
           }

           local tab, beamng_pane, window = mux.spawn_window {
             workspace = 'beamng',
             cwd = '/home/rupel/.local/share/Steam/steamapps/common/BeamNG.drive',
             args = { 'yazi' },
           }
           window:spawn_tab {
             cwd = '/home/rupel/.local/share/Steam/steamapps/common/BeamNG.drive',
             args = { 'claude' },
           }
         end)


         -- Window settings
         config.adjust_window_size_when_changing_font_size = false
         config.enable_scroll_bar = true
         config.scrollback_lines = 200000
         config.window_background_opacity = 0.9
         config.enable_wayland = true -- Force native Wayland (not XWayland)
         config.front_end = "WebGpu" -- Use Vulkan backend on RDNA 4 (avoids OpenGL flicker)
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
           -- Scroll with CTRL+SHIFT (frees up PageUp/PageDown for nvim)
           { key = "PageUp", mods = "CTRL|SHIFT", action = wezterm.action.ScrollByPage(-1.0) },
           { key = "PageDown", mods = "CTRL|SHIFT", action = wezterm.action.ScrollByPage(1.0) },
           { key = "h", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
           { key = "l", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(1) },
           { key = "{", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
           { key = "}", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(1) },
           -- Switch workspaces
           { key = 'i', mods = "CTRL|SHIFT", action = wezterm.action.SwitchWorkspaceRelative(-1) },
           { key = 'o', mods = "CTRL|SHIFT", action = wezterm.action.SwitchWorkspaceRelative(1) },

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
           { key = "DownArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize {"Down" , 2 } },
           { key = "UpArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize {"Up", 2 } },
           { key = "LeftArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize {"Left", 2 } },
           { key = "RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize {"Right", 2 } },

           -- Copy last command + output to clipboard (uses semantic zones from shell integration)
           { key = "c", mods = "CTRL|SHIFT", action = wezterm.action_callback(function(window, pane)
             local zones = pane:get_semantic_zones()
             local output_text, input_text
             for i = #zones, 1, -1 do
               local zone = zones[i]
               if zone.semantic_type == "Output" and not output_text then
                 local text = pane:get_text_from_semantic_zone(zone):gsub("%s+$", "")
                 if text ~= "" then output_text = text end
               elseif zone.semantic_type == "Input" and output_text then
                 input_text = pane:get_text_from_semantic_zone(zone):gsub("%s+$", "")
                 break
               end
             end
             if output_text then
               local result = (input_text and ("$ " .. input_text .. "\n") or "") .. output_text
               window:copy_to_clipboard(result, "Clipboard")
               window:toast_notification("wezterm", "Copied command + output", nil, 2000)
             else
               window:toast_notification("wezterm", "No command output found", nil, 2000)
             end
           end) },
        }

         -- Tabline plugin
         local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
         tabline.setup({
           options = {
             theme = config.color_scheme or "default",
           },
           sections = {
             tabline_a = { "workspace" },
             tabline_b = {},
             tabline_c = { " " },
             tabline_x = {},
             tabline_y = {},
             tabline_z = { "cpu", "ram", { "datetime", style = "%Y-%m-%d %H:%M" }, "battery" },
           },
           tabs = {
             tab_active = { { 'process', padding = { left = 0, right = 1 } } },
             tab_inactive = { { 'process', padding = { left = 0, right = 1 } }, 'output' },
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
