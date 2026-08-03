{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  wallpaperDir = "/home/rupel/Pictures/wallpaper";
  # one image per output; entries for disconnected monitors are simply ignored
  wallpapers = {
    "DP-1" = "${wallpaperDir}/wallhaven-dp98km.png";
    "DP-2" = "${wallpaperDir}/wallhaven-m98579.png";
    "HDMI-A-1" = "${wallpaperDir}/wallhaven-kx8d81.png";
    "HDMI-A-2" = "${wallpaperDir}/wallhaven-kx8d81.png";
  };
in
{
  services.hyprpaper = {
    enable = true;
    package = inputs.hyprpaper.packages.${pkgs.stdenv.hostPlatform.system}.hyprpaper;
    settings = {
      splash = false; # hyprpaper's own splash overlay defaults to ON since rev c011bd2
      wallpaper = lib.mapAttrsToList (monitor: path: { inherit monitor path; }) wallpapers;
    };
  };
  home.packages = with pkgs; [
    # swww
    # inputs.hypr-contrib.packages.${pkgs.stdenv.hostPlatform.system}.grimblast
    hyprpicker
    # inputs.hyprmag.packages.${pkgs.stdenv.hostPlatform.system}.hyprmag
    grim
    slurp
    # wl-clip-persist
    # cliphist
    wf-recorder
    wlinhibit
    libnotify # provides notify-send so keybind/script notifications reach swaync over D-Bus
    # glib
    wayland
    # direnv
  ];
  systemd.user.targets.hyprland-session.Unit.Wants = [
    "xdg-desktop-autostart.target"
  ];
  wayland.windowManager.hyprland = {
    enable = true;
    # Pin the legacy emitter explicitly. The HM module's default flipped from
    # "hyprlang" to "lua", but our whole config (settings + layoutmsg binds) is
    # written in hyprlang syntax, so keep it until we deliberately port to lua.
    configType = "hyprlang";
    xwayland = {
      enable = true;
      # hidpi = true;
    };
    systemd.enable = true;
  };
}
