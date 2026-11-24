{ pkgs, inputs, lib, config, host, ... }:
let
  # Build claude-desktop locally so we can override nodePackages.asar → pkgs.asar
  # (nodePackages was removed from nixpkgs; upstream flake hasn't been updated yet)
  patchy-cnb = pkgs.callPackage "${inputs.claude-desktop}/pkgs/patchy-cnb.nix" {};
  claude-desktop = pkgs.callPackage "${inputs.claude-desktop}/pkgs/claude-desktop.nix" {
    inherit patchy-cnb;
    nodePackages = { asar = pkgs.asar; };
  };
  claude-desktop-with-fhs = pkgs.buildFHSEnv {
    name = "claude-desktop";
    targetPkgs = pkgs: with pkgs; [ docker glibc openssl nodejs uv ];
    runScript = "${claude-desktop}/bin/claude-desktop";
    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cp ${claude-desktop}/share/applications/claude.desktop $out/share/applications/
      mkdir -p $out/share/icons
      cp -r ${claude-desktop}/share/icons/* $out/share/icons/
    '';
  };

  # The hooks settings.json points at. writeShellApplication rather than the
  # hand-written files these came from: runtime dependencies become explicit (a
  # missing jq used to fail at runtime, inside a hook, silently), shellcheck
  # runs at build, and the scripts live in git instead of only in claude-sync.
  #
  # ⚠️ bashOptions must mirror each script's own `set` line. The default adds
  # `errexit`, and a body `set -uo pipefail` does NOT switch it back off — these
  # scripts exit 0 on plenty of non-fatal paths and would abort early under -e.
  mkHook =
    {
      name,
      file,
      bashOptions,
      runtimeInputs,
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs bashOptions;
      text = builtins.readFile file;
    };

  claudeHookPkgs = [
    (mkHook {
      name = "claude-hook-check-ignore-vs-index";
      file = ./claude-hooks/check-ignore-vs-index.sh;
      bashOptions = [
        "nounset"
        "pipefail"
      ];
      runtimeInputs = with pkgs; [
        git
        python3
      ];
    })
    (mkHook {
      name = "claude-hook-check-vault-freshness";
      file = ./claude-hooks/check-vault-freshness.sh;
      bashOptions = [
        "nounset"
        "pipefail"
      ];
      # grep -oP needs GNU grep with PCRE; find/stat/date come from findutils
      # and coreutils. All were previously assumed present.
      runtimeInputs = with pkgs; [
        git
        python3
        gnugrep
        gnused
        findutils
        coreutils
      ];
    })
  ];

  # Workers (drovr.nix) set CLAUDE_WORKER=1 and skip the sync and the
  # session checks: a worker turn is not yours to push or to audit.
  #
  # Bare names only: claude-sync ships settings.json to cordyceps, where a
  # /nix/store path from this machine would dangle. Same rule as the statusline
  # below, and the same reason `claude-sync pull -q` is spelled this way.
  claudeHooks = {
    SessionEnd = [
      # Pushes run on the hourly timer (claude-sync.nix) plus once here, detached so exit doesn't wait
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "test -n \"$CLAUDE_WORKER\" || setsid -f claude-sync-push >/dev/null 2>&1";
          }
        ];
      }
    ];
    SessionStart = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "test -n \"$CLAUDE_WORKER\" || claude-sync-pull";
          }
        ];
      }
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "test -n \"$CLAUDE_WORKER\" || claude-hook-check-ignore-vs-index 2>/dev/null || true";
            timeout = 15;
            statusMessage = "Checking gitignore against the index...";
          }
        ];
      }
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "test -n \"$CLAUDE_WORKER\" || claude-hook-check-vault-freshness 2>/dev/null || true";
            timeout = 15;
            statusMessage = "Checking DECISIONS.md against its source...";
          }
        ];
      }
    ];
  };

  # Statusline for Claude Code. claude-sync syncs settings.json to cordyceps, so
  # it may only reference this by BARE NAME — a /nix/store path would dangle
  # there. home.packages resolves it via /etc/profiles/per-user, stable across
  # generations and identical on both hosts.
  claude-statusline = pkgs.writers.writePython3Bin "claude-statusline"
    { flakeIgnore = [ "E501" ]; } (builtins.readFile ./claude-statusline.py);

  # A Claude Code mod that draws PNGs into the conversation with the terminal's Kitty
  # graphics: a `show` tool for claude, and /image to pin one above the prompt.
  # Every session loads it (the wrapper below). Claude Code draws a mod's Image where
  # the terminal can (kitty, herdr-app) and shows its alt text elsewhere.
  imageMod =
    pkgs.runCommand "claude-mod-inline-image"
      {
        plugin = builtins.toJSON {
          name = "inline-image";
          version = "0.1.0";
          description = "Show PNGs inline in the conversation, drawn by the terminal; /image pins one above the prompt";
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

            // A kitty cell (cell_height 120%) is about this many times taller than wide; herdr's
            // is 2.6, but the mod API gives no cell size in pixels, so there pictures come out ~15% narrow
            const CELL_ASPECT = 2.2
            const MAX_ROWS = 40
            // An Image carries at most this many bytes; a bigger PNG goes by name instead
            const MAX_PNG_BYTES = 2 * 1024 * 1024

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

            // herdr refuses the file medium (t=f, herdr-app#302), so the bytes go inline, read at
            // draw time; only a PNG over MAX_PNG_BYTES goes by name, which kitty reads and herdr does not
            const pngSource = async ($: EngineInterface, path: string) => {
              try {
                const { base64 } = await $.fs.read(path, { as: "bytes" })
                return (base64.length * 3) / 4 <= MAX_PNG_BYTES ? { png: base64 } : { file: path, format: "png" as const }
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

                const source = await pngSource($, img.path)
                if (source === undefined) {
                  return next(e)
                }
                const { Box, Image, Text } = $.ui.resolve(e)
                const { columns, rows } = box(img, e.viewport?.columns)
                const label = img.title || img.path

                return (
                  <Box flexDirection="column">
                    <Text dimColor>{label}</Text>
                    <Image source={source} columns={columns} rows={rows} alt={label} />
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

                const source = await pngSource($, img.path)
                if (source === undefined) {
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
                    <Image source={source} columns={columns} rows={rows} alt={label} />
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

  # Ctrl+G opens nvim in a herdr split under the chat; Enter in NORMAL sends and keeps it open.
  # herdr-app, hc, nvim and wl-paste come from the profile. VISUAL is the bare name, so running
  # sessions get a new version too.
  claude-notepad = pkgs.writeShellApplication {
    name = "claude-notepad";
    runtimeInputs = with pkgs; [ coreutils findutils gnugrep gnused jq ];
    runtimeEnv.NOTEPAD_LUA = ./claude-notepad/notepad.lua;
    text = builtins.readFile ./claude-notepad/claude-notepad.sh;
  };

  # `claude` pulls ~/.claude BEFORE it starts. The SessionStart pull below runs too late for
  # `claude --resume`: its picker lists sessions from local disk before any hook fires, so a
  # session pushed from the other host was missing until the next start. Interactive starts
  # only (not -p/--print, not a pipe, not drovr workers); a waiting lock, because the wezterm
  # startup tabs launch several at once; a timeout, so an offline start is not blocked.
  # claude-sync-pull (claude-sync.nix) by BARE NAME, like the hooks; it skips while a push runs.
  # The SessionStart pull stays as the fallback.
  # It also loads imageMod into every session, whatever the terminal. The variable is set, not
  # appended to, so a copy inherited from an older generation is never loaded twice; load
  # another mod for one session with --plugin-dir.
  claude-code-raw = inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default;
  claude-pull-first = pkgs.writeShellScript "claude" ''
    if [ -z "''${CLAUDE_WORKER:-}" ] && [ -t 0 ] && [ -t 1 ] && command -v claude-sync-pull >/dev/null; then
      interactive=1
      for a in "$@"; do
        case "$a" in -p|--print|-v|--version|-h|--help) interactive=0 ;; esac
      done
      if [ "$interactive" = 1 ]; then
        claude-sync-pull 60 || true
      fi
    fi
    export CLAUDE_CODE_PLUGIN_DIRS=${imageMod}
    if [ -n "''${HC_TERMINAL_ID:-}" ]; then export VISUAL=claude-notepad; fi
    exec ${claude-code-raw}/bin/claude "$@"
  '';
  claude-code = pkgs.symlinkJoin {
    name = "claude-code-pull-first";
    paths = [ claude-code-raw ];
    postBuild = ''
      rm "$out/bin/claude"
      cp ${claude-pull-first} "$out/bin/claude"
    '';
  };
in
{
  # Other modules may add hooks here; the lists concatenate
  # per event, and claudeSettings below writes the merged set.
  options.my.claude.hooks = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.anything);
    default = { };
  };

  config.my.claude.hooks = claudeHooks;

  config.home.packages = claudeHookPkgs ++ [
    claude-code
    claude-notepad
    pkgs.claude-monitor
    claude-statusline
    pkgs.sox # /voice audio recording (provides `rec`)
    claude-desktop-with-fhs
  ];

  # Agent-facing skills that live in their own git repos. They are authored
  # content Claude never writes, so nix owns the path and claude-sync excludes
  # it — a /nix/store symlink must never be synced to a machine that did not
  # build it.
  #
  # beamng-vehicle-values is stable reference material: the pinned input
  # everywhere. interaction-tests is under active development, so on amanita it
  # points at the working tree and an edit is live for the next session; other
  # hosts get the pinned input. Bump either with `nix flake update <input>`.
  config.home.file.".claude/skills/beamng-vehicle-values".source =
    inputs.claude-skill-beamng-vehicle-values;

  config.home.file.".claude/skills/interaction-tests".source =
    if host == "amanita" then
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/projects/interaction-tests"
    else
      inputs.claude-skill-interaction-tests;

  # Relay and Relay Comments for Obsidian, one repo with several skills. Named one by one, so a
  # skill added upstream is not loaded unread; a new one also needs its exclude in claude-sync.nix.
  config.home.file.".claude/skills/relay".source = "${inputs.claude-skill-relay}/skills/relay";
  config.home.file.".claude/skills/relay-comments".source =
    "${inputs.claude-skill-relay}/skills/relay-comments";
  config.home.file.".claude/skills/relay-obsidian-plugin".source =
    "${inputs.claude-skill-relay}/skills/relay-obsidian-plugin";
  config.home.file.".claude/skills/relay-setup".source =
    "${inputs.claude-skill-relay}/skills/relay-setup";
  config.home.file.".claude/skills/relay-self-hosting".source =
    "${inputs.claude-skill-relay}/skills/relay-self-hosting";
  config.home.file.".claude/skills/obsidian-vault-setup".source =
    "${inputs.claude-skill-relay}/skills/obsidian-vault-setup";

  # Esc only does vim's INSERT -> NORMAL; stopping Claude is ctrl+c (any mode) or ctrl+q (NORMAL).
  # Not rebindable: Esc twice on an empty idle prompt still opens the rewind menu (Esc closes it).
  config.home.file.".claude/keybindings.json".text = builtins.toJSON {
    "$schema" = "https://www.schemastore.org/claude-code-keybindings.json";
    "$docs" = "https://code.claude.com/docs/en/keybindings";
    bindings = [
      {
        context = "Chat";
        bindings = {
          escape = null;
          "ctrl+q" = "chat:cancel";
        };
      }
    ];
  };

  # settings.json is Claude-owned and rewritten in place, so home.file would make
  # it read-only and wipe Claude's state. Instead jq merges just our keys on each
  # switch, atomically.
  #
  # ⚠️ `.hooks` is set WHOLESALE, not merged per-event: nix owns the hook set
  # now, so a hook added through Claude's /hooks UI is dropped on the next
  # switch. Add it here instead. Everything else in the file — enabledPlugins,
  # permissions, editorMode — is Claude's and survives untouched.
  # cleanupPeriodDays: the 30-day default deletes synced sessions, and push then deletes them from R2.
  # preferredNotifChannel: Claude's own popups (kitty, Ghostty) stay off, herdr-app does the alerting.
  config.home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.claude/settings.json"
    sl=${lib.escapeShellArg (builtins.toJSON {
      type = "command";
      command = "claude-statusline";
      padding = 0;
    })}
    hk=${lib.escapeShellArg (builtins.toJSON config.my.claude.hooks)}
    mkdir -p "$HOME/.claude"
    if [ -e "$cfg" ]; then
      ${pkgs.jq}/bin/jq --argjson s "$sl" --argjson h "$hk" \
        '.statusLine = $s | .hooks = $h | .cleanupPeriodDays = 36500
          | .preferredNotifChannel = "notifications_disabled"' "$cfg" > "$cfg.hm-tmp"
    else
      ${pkgs.jq}/bin/jq -n --argjson s "$sl" --argjson h "$hk" \
        '{statusLine:$s, hooks:$h, cleanupPeriodDays:36500,
          preferredNotifChannel:"notifications_disabled"}' > "$cfg.hm-tmp"
    fi
    $DRY_RUN_CMD mv "$cfg.hm-tmp" "$cfg"
  '';
}
