{ pkgs, ... }:
{
  programs.mpv = {
    enable = true;

    config = {
      # Catppuccin Macchiato colors
      background-color = "#24273a"; # Base
      osd-back-color = "#181926"; # Crust
      osd-border-color = "#181926"; # Crust
      osd-color = "#cad3f5"; # Text
      osd-shadow-color = "#24273a"; # Base
    };

    # Install modern UI
    scripts = [ pkgs.mpvScripts.uosc ];

    scriptOpts = {
      # Stats script (colors in #BBGGRR format) - press i for status overlay
      stats-border_color = "30201e";
      stats-font_color = "f5d3ca";
      stats-plot_bg_border_color = "c6c6f0";
      stats-plot_bg_color = "30201e";
      stats-plot_color = "c6c6f0";

      # UOSC script colors
      uosc-color = "foreground=f0c6c6,foreground_text=363a4f,background=24273a,background_text=cad3f5,curtain=1e2030,success=a6da95,error=ed8796";
    };
  };
}
