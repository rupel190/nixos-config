{ pkgs, ... }:
{
  programs.cava = {
    enable = true;

    settings = {

      color = {
        gradient = 1;
        gradient_color_1 = "'#8bd5ca'"; # Teal
        gradient_color_2 = "'#91d7e3'"; # Sky
        gradient_color_3 = "'#7dc4e4'"; # Sapphire
        gradient_color_4 = "'#8aadf4'"; # Blue
        gradient_color_5 = "'#c6a0f6'"; # Mauve
        gradient_color_6 = "'#f5bde6'"; # Pink
        gradient_color_7 = "'#ee99a0'"; # Maroon
        gradient_color_8 = "'#ed8796'"; # Red
      };
    };
  };
}
