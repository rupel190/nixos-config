{ pkgs, ... }:
{
  # AGS (Aylur's GTK Shell) - Simple bar widget
  # Config: TypeScript/TSX with minimal bar showing clock + calendar popup

  home.packages = with pkgs; [
    ags # Aylur's GTK Shell
  ];

  # Copy AGS config to ~/.config/ags
  home.file.".config/ags" = {
    source = ./.;
    recursive = true;
  };
}
