{ config, pkgs, ... }:
{
  programs.btop = {
    enable = true;

    settings = {
      color_theme = "catppuccin_macchiato";
      rounded_corners = true;
      theme_background = true;
      graph_symbol = "braille";
      vim_keys = true;
    };
  };

  home.file.".config/btop/themes/catppuccin_macchiato.theme".source = ./catppuccin_macchiato.theme;

}
