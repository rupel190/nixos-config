{ config, pkgs, inputs, ... }:
{

  home.username = "rupel";
  home.homeDirectory = "/home/rupel";


  ### X11 with scaling ###
  home.sessionVariables = {
    GDK_BACKEND = "wayland,x11";
    QT_QPA_PLATFORM = "wayland;xcb";
  };

  # X11 for legacy apps that don't use envars | set cursor size and dpi for 4k monitor
  # xresources.properties = {
  #   "Xcursor.size" = 24;
  # };

  # Auto-load xresources
  xsession.enable = true;

  ####################################################

  # Virt-manager
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [

    digikam
    bitwig-studio
    betterdiscordctl
  ];

  home.stateVersion = "25.05";
}
