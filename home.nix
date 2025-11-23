{
  config,
  pkgs,
  inputs,
  username,
  host,
  ...
}:
{
  imports = [ ./modules/home ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # X11 for legacy apps that don't use envars | set cursor size and dpi for 4k monitor
  # xresources.properties = {
  #   "Xcursor.size" = 24;
  # };

  # Auto-load xresources
  xsession.enable = true;

  home.stateVersion = "25.05";
}
