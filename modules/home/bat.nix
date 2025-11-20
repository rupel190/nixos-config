{ pkgs, ... }:
{
  programs.bat = {
    enable = true;
    config = {
      pager = "less -FR";
      theme = "catppuccin-macchiato";
    };
    extraPackages = with pkgs.bat-extras; [
      # batman
      # batpipe
      # batgrep
      # batdiff
    ];
  };
}
