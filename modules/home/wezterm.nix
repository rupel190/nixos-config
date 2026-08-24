{ pkgs, inputs, ... }:
{
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm; # Stable from nixpkgs (better OpenGL integration)
    # package = inputs.wezterm.packages.${pkgs.stdenv.hostPlatform.system}.default; # Nightly (has OpenGL issues)

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
           pulsemixer_pane:split {
             direction = 'Bottom',
             size = 0.6,
             args = { 'tera' },
           }
           window:spawn_tab {
             args = { 'btop' },
           }

           local tab, claude_pane, window = mux.spawn_window {
             workspace = 'recustomize',
             args = { 'claude' },
             cwd = '/home/rupel/projects/recustomize/stitching-pipeline/',
           }
           window:spawn_tab {
             cwd = '/home/rupel/projects/recustomize/stitching-pipeline/',
           }

           local tab, claude_pane, window = mux.spawn_window {
             workspace = 'nixos',
             args = { 'claude' },
             cwd = '/home/rupel/projects/nixos-config/',
           }
           claude_pane:split {
             direction = 'Bottom',
             size = 0.15,
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


         -- Font: Monaspace Xenon, the slab-serif cut. The Nerd Font patch carries
         -- the fastfetch/tabline glyphs.
         -- Light, not Regular: light-on-dark blooms, worst on the OLED
         config.font = wezterm.font("MonaspiceXe Nerd Font Mono", { weight = "Light" })

         -- Xenon's slabs crowd the rows when set solid; 1.2 gives them air
         config.line_height = 1.2

         -- Monaspace gates ligatures behind stylistic sets, not liga, so wezterm's
         -- default feature list renders none. Setting this replaces the default,
         -- hence kern/liga/clig.
         config.harfbuzz_features = {
           "kern", "liga", "clig", "calt", -- calt = texture healing
           "ss01", -- equal symbols
           "ss02", -- comparisons
           "ss03", -- arrows
           "ss04", -- html tags
           "ss06", -- markdown strings
           "ss09", -- double arrows
           "ss10", -- other tags
           -- Skipped: ss05 (F# pipes, unused here), ss07/ss08 (center the colon
           -- and period globally -- too pervasive for prose)
         }

         -- Window settings
         config.adjust_window_size_when_changing_font_size = false
         -- ROOT-CAUSE FIX for the oscillating/"breathing" window on resize under Hyprland.
         -- Off a tiler, wezterm is its own size authority: it rounds the compositor's
         -- geometry down to whole cells and *requests* that size back to avoid a partial
         -- cell row. Hyprland (also a size authority) re-imposes its tiled geometry and
         -- sends a fresh configure -> the two disagree by a few px forever -> oscillation.
         -- This tells wezterm "you're under a tiler, accept the geometry and letterbox the
         -- leftover pixels" instead of fighting. The no_anim windowrule + thin bottom
         -- splits only reduced how visible the fight was; this removes the driving force.
         -- DO NOT DELETE: silently dropped once in c25b264 (bundled with the WebGpu change),
         -- which is why the symptom kept coming back. XDG_CURRENT_DESKTOP=Hyprland must match.
         config.tiling_desktop_environments = { "Hyprland" }
         config.enable_scroll_bar = true
         config.scrollback_lines = 200000
         config.window_background_opacity = 0.95
         config.enable_wayland = true -- Force native Wayland (not XWayland)
         config.front_end = "WebGpu" -- Use Vulkan backend on RDNA 4 (avoids OpenGL flicker)
         -- Note: window_decorations set after tabline.apply_to_config() at bottom

         -- Tab bar
         config.window_close_confirmation = "NeverPrompt"
         -- Middle-click tab close is hardcoded to confirm=true in wezterm; this hook
         -- reports every pane as non-stateful so no close overlay ever appears.
         wezterm.on('mux-is-process-stateful', function(proc) return false end)
         config.hide_tab_bar_if_only_one_tab = false
         config.show_new_tab_button_in_tab_bar = false

         -- Catppuccin Macchiato theme
         config.color_scheme = "Catppuccin Macchiato"

         config.inactive_pane_hsb = { saturation = 0.8, brightness = 0.8 }
         config.colors = { split = "#c6a0f6" }

         -- Custom keybindings
         config.keys = {
           { key = "UpArrow", mods = "SHIFT", action = wezterm.action.ScrollToPrompt(-1) },
           { key = "DownArrow", mods = "SHIFT", action = wezterm.action.ScrollToPrompt(1) },
           -- Scroll with CTRL+SHIFT (frees up PageUp/PageDown for nvim)
           { key = "PageUp", mods = "CTRL|SHIFT", action = wezterm.action.ScrollByPage(-0.5) },
           { key = "PageDown", mods = "CTRL|SHIFT", action = wezterm.action.ScrollByPage(0.5) },
           { key = "h", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
           { key = "l", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(1) },
           { key = "{", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(-1) },
           { key = "}", mods = "CTRL|SHIFT", action = wezterm.action.MoveTabRelative(1) },
           -- Switch workspaces
           { key = 'i', mods = "CTRL|SHIFT", action = wezterm.action.SwitchWorkspaceRelative(-1) },
           { key = 'o', mods = "CTRL|SHIFT", action = wezterm.action.SwitchWorkspaceRelative(1) },

           -- Disable close tab confirmation
           { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab { confirm = false } },

           -- Rename the current tab; empty input clears it back to the auto title.
           -- Same field as `wezterm cli set-tab-title`, and it always wins over the
           -- OSC title a program sets, so a claude tab keeps the name you gave it.
           { key = "e", mods = "CTRL|SHIFT", action = wezterm.action.PromptInputLine {
             description = "Tab name (empty = auto)",
             action = wezterm.action_callback(function(window, _, line)
               if line then window:active_tab():set_title(line) end
             end),
           } },

           -- Simpler splits
           { key = "|", mods = "CTRL|SHIFT", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
           { key = "_", mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },

           -- Move a pane out to a new window / new tab, or swap panes within a tab
           { key = "n", mods = "CTRL|SHIFT|ALT", action = wezterm.action.PaneSelect { mode = "MoveToNewWindow" } },
           { key = "t", mods = "CTRL|SHIFT|ALT", action = wezterm.action.PaneSelect { mode = "MoveToNewTab" } },
           { key = "s", mods = "CTRL|SHIFT|ALT", action = wezterm.action.PaneSelect { mode = "SwapWithActive" } },

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

         -- Tab titles. Panes live on the `unix` mux domain, where the GUI cannot see a
         -- pane's foreground process, so tabline's `process` component silently falls
         -- back to the pane's OSC title -- a full cwd path, or Claude's entire
         -- conversation title. Derive a short title instead.
         local TAB_TITLE_WIDTH = 24

         local function basename(path)
           return path:gsub("/+$", ""):match("([^/]+)$") or path
         end

         local function cwd_name(pane)
           local cwd = pane and pane.current_working_dir
           if not cwd then return nil end
           local path = type(cwd) == "string" and cwd or (cwd.file_path or cwd.path or tostring(cwd))
           -- cwd URLs often carry a trailing slash; strip it (but keep a bare "/")
           path = (path:gsub("^%a+://[^/]*", ""):gsub("(.)/+$", "%1"))
           if path == wezterm.home_dir then return "~" end
           return basename(path)
         end

         -- Truncate on a word boundary, in display cells (not bytes)
         local function shorten(text, max)
           if wezterm.column_width(text) <= max then return text end
           local cut = wezterm.truncate_right(text, max - 1)
           if not text:sub(#cut + 1, #cut + 1):match("%s") then
             local whole = cut:gsub("%s+%S*$", "") -- cut landed mid-word, drop that word
             if wezterm.column_width(whole) >= max / 2 then cut = whole end
           end
           return cut .. "…"
         end

         -- Claude prefixes its title with a status glyph: braille frames while it works,
         -- ✳ when idle. Keep the glyph (it animates -> a busy tab is visible at a glance).
         local function split_status_glyph(title)
           local head, rest = title:match("^(%S+)%s+(.+)$")
           if not head then return nil end
           local b1, b2 = head:byte(1), head:byte(2)
           if head == "✳" or (b1 == 0xE2 and b2 and b2 >= 0xA0 and b2 <= 0xA3) then
             return head, rest
           end
           return nil
         end

         -- Claude Code sessions announce "I want something" by dropping a marker file
         -- named <pane-id>.<status> here; ~/.claude/hooks/wezterm-status.sh writes it on
         -- the Notification hook and removes it once the prompt is answered. A file
         -- rather than a user var because claude's hooks have no controlling terminal,
         -- and writing the SetUserVar escape to claude's pty injects bytes into a
         -- fullscreen TUI mid-repaint -- enough to wedge the terminal's colour state.
         local CLAUDE_ATTENTION_DIR = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/claude-attention"
         local CLAUDE_ALERTS = {
           permission = { icon = wezterm.nerdfonts.md_shield_alert, fg = "#181926", bg = "#ed8796" },
           waiting = { icon = wezterm.nerdfonts.md_message_alert, fg = "#181926", bg = "#f5a97f" },
         }

         -- wezterm.glob is async ("attempt to yield from outside a coroutine") and
         -- format-tab-title is not, so the directory is read on the status tick
         -- (status_update_interval, 500ms) and the result cached for the renderer.
         local claude_markers = {}
         wezterm.on("update-status", function()
           local ok, markers = pcall(wezterm.glob, CLAUDE_ATTENTION_DIR .. "/*")
           claude_markers = ok and markers or {}
         end)

         -- Claude can sit in any pane of the tab, not only the active one.
         -- A marker outlives its session when claude dies without firing the clear hook,
         -- and WEZTERM_PANE is only unique within one mux -- a standalone wezterm numbers
         -- its panes from 0 again, so markers collide with unrelated panes here. Both
         -- leave a shell wearing an alert; require the pane to still look like claude.
         local function claude_alert(tab)
           local markers = claude_markers
           if #markers == 0 then return nil end

           local panes = tab.panes
           if type(panes) ~= "table" or #panes == 0 then panes = { tab.active_pane } end
           for _, pane in ipairs(panes) do
             local id = pane and pane.pane_id
             if id and split_status_glyph(pane.title or "") then
               for _, marker in ipairs(markers) do
                 local pane_id, status = marker:match("([^/]+)%.([^.]+)$")
                 if tonumber(pane_id) == id and CLAUDE_ALERTS[status] then
                   return CLAUDE_ALERTS[status]
                 end
               end
             end
           end
         end

         local function tab_body(tab, pane, alert)
           -- An explicit title (Ctrl+Shift+E, `wezterm cli set-tab-title`) always wins
           if tab.tab_title and #tab.tab_title > 0 then
             return shorten(tab.tab_title, TAB_TITLE_WIDTH)
           end

           local title = pane.title or ""
           local glyph, rest = split_status_glyph(title)
           if glyph then
             -- an alert icon replaces Claude's own status glyph
             return (alert and "" or glyph .. " ") .. shorten(rest, TAB_TITLE_WIDTH)
           end

           -- Local (non-mux) panes still report a real process name
           local proc = pane.foreground_process_name
           if proc and #proc > 0 then
             proc = basename(proc)
             if proc ~= "fish" and proc ~= "bash" then return proc end
           end

           -- A path-ish or empty title is worth no more than its leaf directory
           if title == "" or title:match("^[~/]") or title:match("^%a+://") then
             return cwd_name(pane) or "shell"
           end
           return shorten(title, TAB_TITLE_WIDTH)
         end

         local function tab_title(tab)
           local pane = tab.active_pane or {}
           local alert = claude_alert(tab)
           local text = tab_body(tab, pane, alert)
           if alert then text = (alert.icon or "!") .. " " .. text end
           return text .. " "
         end

         -- Tabline plugin
         local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

         -- Paint the entire tab chip (body *and* its powerline separators) while a
         -- Claude session in it is waiting on you. tabline re-reads its theme for every
         -- tab it formats, so retinting theme.tab right before it draws colours exactly
         -- one tab. We must drive that draw ourselves: wezterm gives format-tab-title to
         -- the FIRST handler registered and takes whatever it returns as final -- nil
         -- included -- so a pre-hook that returns nil doesn't fall through to tabline,
         -- it silently drops you back to wezterm's built-in "index: title" tab bar.
         --
         -- Only the inactive slots are ever retinted: colour answers two questions here
         -- and they must not compete. Fill = where am I (mauve pill), fill = what wants
         -- me (red/peach) only on tabs I'm not on, icon = which prompt is pending.
         local tab_theme_default
         wezterm.on("format-tab-title", function(tab, _, _, _, hover, _)
           local ok, theme = pcall(tabline.get_theme)
           if ok and type(theme) == "table" and theme.tab then
             tab_theme_default = tab_theme_default or {
               inactive = { fg = theme.tab.inactive.fg, bg = theme.tab.inactive.bg },
               inactive_hover = { fg = theme.tab.inactive_hover.fg, bg = theme.tab.inactive_hover.bg },
             }
             local alert = not tab.is_active and claude_alert(tab) or nil
             for _, key in ipairs({ "inactive", "inactive_hover" }) do
               local colors = alert or tab_theme_default[key]
               theme.tab[key].fg = colors.fg
               theme.tab[key].bg = colors.bg
             end
           end
           return require("tabline.tabs").set_title(tab, hover)
         end)

         tabline.setup({
           options = {
             theme = config.color_scheme or "default",
             -- Stock Catppuccin puts the *brighter* text on inactive tabs and separates
             -- them from the active one by ~9 L* -- unreadable across a wide bar. Flip
             -- it: active is a filled mauve pill (also the scheme's own active-tab
             -- colour, and config.colors.split), idle tabs recede to overlay1.
             theme_overrides = {
               tab = {
                 active = { fg = "#181926", bg = "#c6a0f6" },
                 inactive = { fg = "#8087a2" },
                 inactive_hover = { fg = "#cad3f5", bg = "#363a4f" },
               },
             },
           },
           sections = {
             tabline_a = { "workspace" },
             tabline_b = {},
             tabline_c = { " " },
             tabline_x = {},
             tabline_y = {},
             tabline_z = { "cpu", "ram", { "datetime", style = "%Y-%m-%d %H:%M" }, "battery" },
             -- These live under `sections`, NOT a `tabs` key: tabline has no such key,
             -- so a `tabs = {...}` block is silently ignored and every tab falls back to
             -- the plugin defaults (index + process). That is what happened between
             -- f935941 and now -- the titles below never actually rendered.
             -- A bare table in a section is emitted as a literal format item
             -- (util.extract_components), so weight is a second, colour-independent
             -- "you are here" cue; reset it so the trailing separator stays normal.
             tab_active = {
               { Attribute = { Intensity = "Bold" } },
               tab_title,
               { Attribute = { Intensity = "Normal" } },
             },
             tab_inactive = {
               tab_title,
               -- Unseen-output cue on backgrounded tabs (e.g. Claude finished / is waiting).
               -- Blank when idle so the bell only shows on activity and actually pops;
               -- WezTerm auto-clears unseen-output state when the tab regains focus.
               {
                 'output',
                 icon = { wezterm.nerdfonts.md_bell_ring, color = { fg = '#f9e2af' } },
                 icon_no_output = "",
               },
             },
           },
         })
         tabline.apply_to_config(config)

         -- Override tabline's decoration settings (must be AFTER apply_to_config)
         config.window_decorations = "NONE"
         config.integrated_title_buttons = {}

         -- Links: plain click opens them; wezterm's default rules already match any \w+://
         -- scheme incl. file://, so no custom rule is needed. Inside a TUI that grabs the
         -- mouse (Claude Code sends ?1000h), Shift+Click bypasses the grab.

         return config
      '';
  };
}
