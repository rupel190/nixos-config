{ pkgs, inputs, lib, ... }:
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
in
{
  home.packages = [
    inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.claude-monitor
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
}
