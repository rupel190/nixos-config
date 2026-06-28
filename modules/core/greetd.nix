{ config, pkgs, lib, ... }:
# greetd + tuigreet: a minimal TTY login manager replacing the implicit LightDM.
# Newer nixpkgs no longer auto-enable a display manager from services.xserver.enable,
# so without this a rebuild drops to a bare TTY. greetd makes the login deterministic.
let
  # tuigreet's --theme takes NAMED colours (blue, magenta, cyan, …). Those names resolve
  # through the Linux console palette, which we repaint to Catppuccin Macchiato in system.nix
  # (console.colors). So "magenta" renders as Catppuccin pink (#f5bde6), "cyan" as teal, etc.
  tuigreetTheme = lib.concatStringsSep ";" [
    "border=blue"      # box around the login form  → Catppuccin blue
    "text=white"       # general text                → subtext1
    "prompt=cyan"      # field labels (Username:)    → teal
    "time=magenta"     # clock at the top            → pink
    "action=blue"      # F-key / session hints       → blue
    "button=magenta"   # focused button              → pink
    "container=black"  # form background             → base (blends with bg)
    "input=white"      # what you type               → subtext1
  ];

  # Read the real wayland-sessions directory so tuigreet launches the same Hyprland
  # entry (Exec=start-hyprland) that LightDM used — no change to how Hyprland comes up.
  sessions = "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";

  tuigreetCmd = lib.concatStringsSep " " [
    "${pkgs.tuigreet}/bin/tuigreet"
    "--time"                       # show a clock
    "--asterisks"                  # mask the password with *
    "--remember"                   # remember the last username
    "--remember-session"           # remember the last chosen session
    "--greeting 'amanita ❄'"       # header text
    "--sessions ${sessions}"       # list sessions from the real wayland-sessions dir
    "--theme '${tuigreetTheme}'"
  ];
in
{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = tuigreetCmd;
      user = "greeter";
    };
  };
}
