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

  # term-image MCP server (shows images in a side WezTerm pane). server.py
  # comes from the pinned wezterm-image-mcp flake input; launched via uv with
  # the Nix python so uv doesn't download a non-runnable interpreter on NixOS.
  termImageServer = {
    type = "stdio";
    command = "${pkgs.uv}/bin/uv";
    args = [ "run" "--python" "${pkgs.python3}/bin/python3" "${inputs.wezterm-image-mcp}/server.py" ];
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
      name = "claude-hook-notify";
      file = ./claude-hooks/notify.sh;
      bashOptions = [ "nounset" ];
      # wezterm is pkgs.wezterm here too (see wezterm.nix), so naming it costs
      # no extra build. The script still guards with `command -v`.
      runtimeInputs = with pkgs; [
        jq
        wezterm
        libnotify
        gnused
        coreutils
      ];
    })
    (mkHook {
      name = "claude-hook-wezterm-status";
      file = ./claude-hooks/wezterm-status.sh;
      bashOptions = [ "nounset" ];
      runtimeInputs = with pkgs; [
        jq
        coreutils
      ];
    })
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

  # Bare names only: claude-sync ships settings.json to cordyceps, where a
  # /nix/store path from this machine would dangle. Same rule as the statusline
  # below, and the same reason `claude-sync pull -q` is spelled this way.
  claudeHooks = {
    Notification = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "claude-hook-notify";
          }
          {
            type = "command";
            command = "claude-hook-wezterm-status set";
          }
        ];
      }
    ];
    PostToolUse = [
      {
        matcher = "*";
        hooks = [
          {
            type = "command";
            command = "claude-hook-wezterm-status clear";
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
            command = "claude-sync pull -q";
          }
        ];
      }
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "claude-hook-check-ignore-vs-index 2>/dev/null || true";
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
            command = "claude-hook-check-vault-freshness 2>/dev/null || true";
            timeout = 15;
            statusMessage = "Checking DECISIONS.md against its source...";
          }
        ];
      }
    ];
    Stop = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "claude-hook-wezterm-status clear";
          }
        ];
      }
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "claude-sync push -q";
          }
        ];
      }
    ];
    UserPromptSubmit = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "claude-hook-wezterm-status clear";
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
in
{
  home.packages = claudeHookPkgs ++ [
    inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.claude-monitor
    claude-statusline
    pkgs.sox # /voice audio recording (provides `rec`)
    claude-desktop-with-fhs
  ];

  # Register term-image declaratively by merging it into ~/.claude.json — the
  # file Claude owns and rewrites constantly, so we can't manage it with
  # home.file (that would make it read-only and wipe Claude's state). Instead
  # we jq-merge just our one entry on each switch, atomically, preserving
  # everything else. Same result as `claude mcp add -s user`, but reproducible
  # and without a CLI wrapper (--mcp-config is variadic and breaks subcommands).
  home.activation.termImageMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.claude.json"
    entry=${lib.escapeShellArg (builtins.toJSON termImageServer)}
    if [ -e "$cfg" ]; then
      ${pkgs.jq}/bin/jq --argjson e "$entry" '.mcpServers."term-image" = $e' "$cfg" > "$cfg.hm-tmp"
    else
      ${pkgs.jq}/bin/jq -n --argjson e "$entry" '{mcpServers:{"term-image":$e}}' > "$cfg.hm-tmp"
    fi
    $DRY_RUN_CMD mv "$cfg.hm-tmp" "$cfg"
  '';

  # Agent-facing skills that live in their own git repos. They are authored
  # content Claude never writes, so nix owns the path and claude-sync excludes
  # it — a /nix/store symlink must never be synced to a machine that did not
  # build it.
  #
  # beamng-vehicle-values is stable reference material: the pinned input
  # everywhere. interaction-tests is under active development, so on amanita it
  # points at the working tree and an edit is live for the next session; other
  # hosts get the pinned input. Bump either with `nix flake update <input>`.
  home.file.".claude/skills/beamng-vehicle-values".source =
    inputs.claude-skill-beamng-vehicle-values;

  home.file.".claude/skills/interaction-tests".source =
    if host == "amanita" then
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/projects/interaction-tests"
    else
      inputs.claude-skill-interaction-tests;

  # settings.json is Claude-owned and rewritten in place, so home.file would make
  # it read-only. Merge just our keys, same approach as termImageMcp above.
  #
  # ⚠️ `.hooks` is set WHOLESALE, not merged per-event: nix owns the hook set
  # now, so a hook added through Claude's /hooks UI is dropped on the next
  # switch. Add it here instead. Everything else in the file — enabledPlugins,
  # permissions, editorMode — is Claude's and survives untouched.
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="$HOME/.claude/settings.json"
    sl=${lib.escapeShellArg (builtins.toJSON {
      type = "command";
      command = "claude-statusline";
      padding = 0;
    })}
    hk=${lib.escapeShellArg (builtins.toJSON claudeHooks)}
    mkdir -p "$HOME/.claude"
    if [ -e "$cfg" ]; then
      ${pkgs.jq}/bin/jq --argjson s "$sl" --argjson h "$hk" \
        '.statusLine = $s | .hooks = $h' "$cfg" > "$cfg.hm-tmp"
    else
      ${pkgs.jq}/bin/jq -n --argjson s "$sl" --argjson h "$hk" \
        '{statusLine:$s, hooks:$h}' > "$cfg.hm-tmp"
    fi
    $DRY_RUN_CMD mv "$cfg.hm-tmp" "$cfg"
  '';
}
