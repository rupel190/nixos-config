{
  config,
  inputs,
  pkgs,
  ...
}:
let
  agsPkgs = inputs.ags.packages.${pkgs.stdenv.hostPlatform.system};

  # mkOutOfStoreSymlink needs a real path outside /nix/store, so this can't be
  # derived from `./.` — that would copy the tree into the store, which is the
  # exact thing we're avoiding. Hardcodes the repo location; if the checkout ever
  # moves, this string moves with it.
  configSrc = "${config.home.homeDirectory}/projects/nixos-config/modules/home/ags";
in
{
  # AGS 3 (Astal + TypeScript, GTK4) status bar.
  # Widgets live next to this file; see widget/Bar.tsx for the layout.
  imports = [ inputs.ags.homeManagerModules.default ];

  programs.ags = {
    enable = true;

    # Left null on purpose. The module implements this option as
    # `xdg.configFile."ags".source = cfg.configDir`, which copies the tree into
    # the store and leaves ~/.config/ags read-only — every CSS tweak would then
    # cost a home-manager rebuild. The symlink at the bottom replaces it.
    configDir = null;

    # Runs `ags run` as a user unit bound to graphical-session.target, so it
    # starts and stops with the compositor. Replaces an exec-once in hyprland.
    systemd.enable = true;

    # Astal libraries. These are plain C/GObject libraries consumed over
    # GObject-Introspection; listing one here puts its typelib on gjs's runtime
    # path, which is what makes `import X from "gi://AstalX"` resolve at all.
    # Listed up front so adding an indicator is a file edit, not a rebuild.
    #
    # NOTE: do not try to get these by setting `package = agsPkgs.agsFull`. The
    # module re-runs `.override { extraPackages = cfg.extraPackages; }` on
    # whatever package it is handed, which resets agsFull's list straight back
    # to empty. extraPackages is the only channel that survives.
    extraPackages = with agsPkgs; [
      hyprland # workspaces + active window over the Hyprland IPC socket
      apps # .desktop entry lookup — resolves a window class to a themed icon
      tray # StatusNotifierItem system tray
      wireplumber # audio sinks/sources + volume
      network # NetworkManager
      bluetooth # bluez
      mpris # media player metadata (spotify)
      battery # upower — matters on cordyceps
      powerprofiles # power-profiles-daemon
    ];
    # Intentionally absent: astal `notifd`. It is not a passive reader — calling
    # AstalNotifd.get_default() acquires org.freedesktop.Notifications on the
    # bus, which would fight swaync (enabled in packages.nix) for ownership.
  };

  # Point ~/.config/ags straight at the working tree instead of the store, so a
  # .tsx or .scss edit only needs `systemctl --user restart ags`.
  xdg.configFile."ags".source = config.lib.file.mkOutOfStoreSymlink configSrc;
}
