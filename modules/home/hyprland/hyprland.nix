{ inputs, pkgs, ... }:
let
  wallpaper = "/home/rupel/Pictures/wallpaper/20251204024944_1.jpg";
  mkWallpaper = monitor: { inherit monitor; path = wallpaper; };
in
{
  services.hyprpaper = {
    enable = true;
    package = inputs.hyprpaper.packages.${pkgs.stdenv.hostPlatform.system}.hyprpaper;
    settings = {
      wallpaper = map mkWallpaper [ "DP-1" "DP-2" "HDMI-A-1" "HDMI-A-2" ];
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
