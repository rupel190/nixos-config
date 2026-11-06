{ pkgs, lib, ... }:

# Herdr — terminal multiplexer for AI coding agents (github.com/herdrdev/herdr).
#
# Packaged in nixpkgs unstable (herdr 0.9.5), so no custom derivation is needed.
# The config is a read-only symlink into the Nix store: edit this file, not
# ~/.config/herdr/config.toml, then rebuild.
#
# Full schema: https://herdr.dev/tui/docs/config-reference/

{
  home.packages = (with pkgs; [ herdr ]);

  xdg.configFile."herdr/config.toml".text = ''
    # Herdr config — managed by modules/home/herdr.nix
    # Edit the Nix source and rebuild; do not edit the symlinked file directly.

    # Skip first-run onboarding flow.
    onboarding = false

    # Herdr never polls herdr.dev for versions/manifests; changes come via
    # `nix flake update` instead. Re-enable manifest checks with = true.
    [update]
    version_check = false
    manifest_check = false

    # herdr only ships catppuccin (mocha) and catppuccin-latte, so Macchiato (as in
    # GTK, bat, yazi, btop, ...) is the built-in theme plus the overrides below.
    [theme]
    name = "catppuccin"

    [theme.custom]
    sidebar_bg = "#1e2030"    # mantle
    active_row_bg = "#24273a" # base
    selection_bg = "#363a4f"  # surface0
    accent = "#8bd5ca"        # teal, as in the GTK/cursor theme
    green = "#a6da95"
    blue = "#8aadf4"
    red = "#ed8796"
    yellow = "#eed49f"

    # Herdr's default prefix. Not ctrl+z: that is the shell's suspend-job key.
    [keys]
    prefix = "ctrl+b"
    # alt+hjkl without the prefix; kitty already owns alt+1-9 and ctrl+alt+hjkl.
    previous_tab = "alt+h"
    next_tab = "alt+l"
    previous_workspace = "alt+k"
    next_workspace = "alt+j"
    # Example custom command (uncomment and adjust):
    # [[keys.command]]
    # key = "prefix+alt+g"
    # type = "popup"
    # command = "lazygit"
    # description = "open lazygit"

    # Show the detected agent (Claude Code, OpenCode, ...) on split-pane borders.
    [ui]
    show_agent_labels_on_pane_borders = true

    # Resume agent conversations after a Herdr server restart.
    [session]
    resume_agents_on_restore = true
    startup_per_agent_delay_ms = 100

    # New panes inherit the source pane's workspace directory by default.
    [terminal]
    new_cwd = "follow"
    default_shell = "fish"
  '';
}
