{ config, pkgs, ... }:
{
  # opencode 2.0 dropped its CLAUDE.md fallback; live link so claude-sync edits apply to both.
  xdg.configFile."opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/CLAUDE.md";

  # opencode — provider-agnostic terminal coding agent (sst/opencode).
  programs.opencode = {
    enable = true;

    settings = {
      # Self-update would try to replace a read-only store binary; the flake pins it.
      autoupdate = false;

      # opencode otherwise downloads prebuilt LSP servers, which don't run on NixOS.
      lsp.nix = {
        command = [ "${pkgs.nixd}/bin/nixd" ];
        extensions = [ ".nix" ];
      };
    };

    # Reuse the WezTerm palette (Catppuccin Macchiato) instead of a second theme.
    tui.theme = "system";
  };
}
