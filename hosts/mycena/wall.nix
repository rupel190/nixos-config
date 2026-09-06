# Wall-panel session for mycena: Phosh, the mobile shell (phoc + GTK).
#
# Why a PHONE shell on a 13.5" tablet: when mycena is on the wall its base is
# off, so there is no keyboard and no mouse — only touch. That rules out both
# obvious answers:
#   - cage (kiosk) ships NO wlr-layer-shell (verified: zero layer-shell symbols
#     in the 0.3.1 binary), and every Wayland OSK is a layer-shell client, so
#     text input is impossible under it.
#   - sway solves the OSK but is keybinding-driven: with no keyboard you cannot
#     launch or switch anything, and its launcher expects typing.
# Phosh is built for exactly this input model — tap-to-launch app grid, an OSK
# that raises itself on text focus, and swipe switching.
#
# The NixOS module runs phosh-session as a systemd unit on tty1 with
# PAMName=login and Restart=always, so autologin and crash recovery come for
# free — do NOT add greetd or a display manager here. It also declares
# xdg.portal, pulls in the `stevia` OSK, and sets i18n.inputMethod to ibus with
# the Wayland frontend, without which stevia does not raise on text fields.
{
  pkgs,
  username,
  ...
}:
{
  services.xserver.desktopManager.phosh = {
    enable = true;
    user = username;
    group = "users";

    phocConfig = {
      # Lazily-started XWayland, so non-Wayland apps still run. Costs nothing
      # until something actually needs it.
      xwayland = "true";

      # The module's default targets DSI-1, a phone panel. This machine's only
      # output is eDP-1 at 3000x2000 (confirmed via /sys/class/drm).
      #
      # ~267 PPI at 13.5". scale 2 gives 1500x1000 logical; raise to 2.5 or 3
      # if the shell reads too small from across the room.
      outputs."eDP-1" = {
        mode = "3000x2000";
        scale = 2;
      };
    };
  };

  hardware.graphics.enable = true; # Intel HD 520

  fonts.packages = with pkgs; [
    dejavu_fonts
    noto-fonts
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    pciutils # `lspci` was missing when first probing this host
    usbutils
    brightnessctl # panel backlight; no function keys when detached
  ];
}
