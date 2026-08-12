{ pkgs, config, ... }:
{
  fonts.fontconfig = {
    enable = true;
    # <prefer> prepends, so DejaVu/Noto stay behind for scripts Geist lacks
    defaultFonts = {
      sansSerif = [ "Geist" ];
      monospace = [ "MonaspiceXe Nerd Font Mono" ];
    };
  };

  home.packages = with pkgs; [
    geist-font
    nerd-fonts.monaspace
  ];

  gtk = {
    enable = true;

    # Interface font: also what Firefox/Electron resolve CSS system-ui to
    font = {
      name = "Geist";
      size = 11;
    };

    theme = {
      name = "catppuccin-macchiato-teal-standard";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "teal" ];
        variant = "macchiato";
        # nixpkgs 0711 defaults python3 to 3.14, whose argparse.BooleanOptionalAction
        # rejects the `type=` kwarg catppuccin-gtk's build.py passes → build crash.
        # Build with 3.13 (still accepts type=) until upstream catppuccin-gtk is 3.14-ready.
        python3 = pkgs.python313;
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
    enable = true;
    name = "catppuccin-macchiato-teal-cursors";
    package = pkgs.catppuccin-cursors.macchiatoTeal;
    size = 24;
    gtk.enable = true;
  };
}
