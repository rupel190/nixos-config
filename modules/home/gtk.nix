{ pkgs, config, ... }:
{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    geist-font # TODO: is this nerd font?!
  ];

  gtk = {
    enable = true;

    font = {
      name = "GeistMono Nerd Font Mono";
      size = 11;
    };

    theme = {
      name = "catppuccin-macchiato-teal-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "teal" ];
        variant = "macchiato";
      };
    };

    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };

    cursorTheme = {
      name = "catppuccin-macchiato-teal-cursors";
      package = pkgs.catppuccin-cursors.macchiatoTeal;
      size = 24;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4 = {
      theme = config.gtk.theme;
      extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };
  };

  home.pointerCursor = {
    name = "catppuccin-macchiato-teal-cursors";
    package = pkgs.catppuccin-cursors.macchiatoTeal;
    size = 24;
    gtk.enable = true;
  };
}
