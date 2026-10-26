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

  # A Claude Code mod that draws PNGs into the conversation through kitty's own
  # image support: a `show` tool for claude, and /image to pin one above the prompt.
  # Claude Code draws a mod's Image only in kitty-like terminals, so only sessions
  # started in kitty load it (the env line below); WezTerm's use the term-image MCP.
  imageMod =
    pkgs.runCommand "claude-mod-inline-image"
      {
        plugin = builtins.toJSON {
          name = "inline-image";
          version = "0.1.0";
          description = "Show PNGs inline in the conversation, drawn by kitty; /image pins one above the prompt";
          types = "./types/index.d.ts";
        };
        hooks = builtins.toJSON { modules = [ "./register.tsx" ]; };
        # The contract for the module's $.state
        types = ''
          export type Shown = { path: string; title: string; width: number; height: number }

          declare module "claude-code" {
            interface PluginState {
              "inline-image": { shown: Shown | null }
            }
          }
        '';
        register = # tsx
          ''
            import { atom, read, update } from "claude-code"
            import type { EngineInterface, Register } from "claude-code"

            import type { Shown } from "../types"

            const TOOL_NAME = "mcp__inline-image__show"
            // A pattern: the laid types list only tools connected at the last reload
            const TOOL = /^mcp__inline-image__show$/
            const shown = atom({ plugin: "inline-image", key: "shown" } as const, null)

            // A cell is about this many times taller than wide (cell_height 120%)
            const CELL_ASPECT = 2.2
            const MAX_ROWS = 20

            // Reads the PNG's size from its header; answers the picture, or a problem
            const probe = async ($: EngineInterface, path: string, title: string): Promise<Shown | string> => {
              if (!path.startsWith("/") || !path.toLowerCase().endsWith(".png")) {
                return "needs the absolute path of a .png file"
              }
              try {
                const { base64 } = await $.fs.read(path, { as: "bytes" })
                // IHDR: width and height are big-endian 32-bit at bytes 16 and 20
                const head = atob(base64.slice(0, 32))
                const u32 = (at: number) =>
                  ((head.charCodeAt(at) << 24) | (head.charCodeAt(at + 1) << 16) | (head.charCodeAt(at + 2) << 8) | head.charCodeAt(at + 3)) >>> 0
                return { path, title, width: u32(16), height: u32(20) }
              } catch {
                return "cannot read " + path
              }
            }

            // The cell box that keeps the picture's shape: MAX_ROWS tall, or narrower if the width runs out
            const box = (img: Shown, viewportColumns: number | undefined) => {
              const maxColumns = Math.min(255, Math.max(10, (viewportColumns ?? 80) - 4))
              let rows = MAX_ROWS
              let columns = Math.round((rows * CELL_ASPECT * img.width) / img.height)
              if (columns > maxColumns) {
                columns = maxColumns
                rows = Math.max(1, Math.round((columns * img.height) / (img.width * CELL_ASPECT)))
              }
              return { columns, rows }
            }

            // A plugin tool answers text, so the picture travels as JSON in it
            const parseShown = (output: unknown): Shown | undefined => {
              if (typeof output !== "string") {
                return undefined
              }
              try {
                const value: unknown = JSON.parse(output)
                return typeof value === "object" && value !== null && typeof (value as Shown).path === "string" ? (value as Shown) : undefined
              } catch {
                return undefined
              }
            }

            export const register: Register = on => {
              on("session.start", async ($, e, next) => {
                await $.tool.register({
                  name: "show",
                  description:
                    "Show a PNG image inline in the conversation, drawn by the terminal where the call appears. " +
                    "Takes the absolute path of a .png file and an optional title.",
                  inputSchema: {
                    type: "object",
                    properties: { path: { type: "string" }, title: { type: "string" } },
                    required: ["path"],
                  },
                  isDeferred: false,
                })
                await $.command.register({
                  name: "image",
                  description: "Pin a PNG above the prompt: /image <path>; /image alone unpins it",
                })

                return next(e)
              })

              // The picture travels in the result, so the row can draw it whenever it is drawn again
              on("tool.call", { tool: TOOL }, async ($, e) => {
                // The tool's own arguments sit beside `tool` on the event
                const input = e as unknown as { path?: unknown; title?: unknown }
                const img = await probe($, String(input.path ?? ""), String(input.title ?? ""))

                return typeof img === "string" ? { deny: img } : { result: JSON.stringify(img) }
              })

              on("ui.render", { component: "ToolResult" }, async ($, e, next) => {
                const img = parseShown(e.props.output)
                if (e.props.tool !== TOOL_NAME || e.props.isErrored || e.surface !== "terminal" || img === undefined) {
                  return next(e)
                }

                const { Box, Image, Text } = $.ui.resolve(e)
                const { columns, rows } = box(img, e.viewport?.columns)
                const label = img.title || img.path

                return (
                  <Box flexDirection="column">
                    <Text dimColor>{label}</Text>
                    <Image source={{ file: img.path, format: "png" }} columns={columns} rows={rows} alt={label} />
                  </Box>
                )
              })

              on("command.run", { command: "image" }, async ($, e) => {
                const path = e.args.trim()
                if (path === "") {
                  await update($, shown, () => null)
                  return { text: "Image unpinned." }
                }

                const img = await probe($, path, "")
                if (typeof img === "string") {
                  return { text: img }
                }
                await update($, shown, () => img)

                return { text: "Pinned " + path + " above the prompt." }
              })

              on("ui.render", { component: "AbovePrompt" }, async ($, e, next) => {
                const img = await read($, shown)
                if (img === null || e.surface !== "terminal" || e.props.hasSurvey) {
                  return next(e)
                }

                const { Box, Button, Image, Text } = $.ui.resolve(e)
                const { columns, rows } = box(img, e.viewport?.columns)
                const label = img.title || img.path

                return (
                  <Box flexDirection="column">
                    <Box>
                      <Text dimColor>{label} </Text>
                      <Button key="close" label="Close" onPress={() => update($, shown, () => null)} />
                    </Box>
                    <Image source={{ file: img.path, format: "png" }} columns={columns} rows={rows} alt={label} />
                  </Box>
                )
              })
            }
          '';
        passAsFile = [
          "plugin"
          "hooks"
          "types"
          "register"
        ];
      }
      ''
        install -Dm444 "$pluginPath" $out/.claude-plugin/plugin.json
        install -Dm444 "$hooksPath" $out/hooks/hooks.json
        install -Dm444 "$typesPath" $out/types/index.d.ts
        install -Dm444 "$registerPath" $out/hooks/register.tsx
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

    # The first four: what a WezTerm shell passes on when kitty is started from one.
    # Left in, claude's tab hook would paint a WezTerm tab and programs would think
    # they run in WezTerm. The last: every claude started in kitty loads the image mod.
    extraConfig = ''
      env WEZTERM_PANE
      env WEZTERM_UNIX_SOCKET
      env TERM_PROGRAM
      env TERM_PROGRAM_VERSION
      env CLAUDE_CODE_PLUGIN_DIRS=${imageMod}
    '';
  };
}
