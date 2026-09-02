{ pkgs, ... }:
{
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
