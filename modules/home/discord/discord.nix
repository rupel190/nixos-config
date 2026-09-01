{ pkgs, ... }:
{
  home.packages = with pkgs; [
    discord # official client, kept vanilla as a fallback
  ];

  # Vesktop: Discord web + Vencord, own config dir. Settings deliberately left mutable —
  # declaring them writes /nix/store symlinks and the in-app toggles stop saving.
  programs.vesktop.enable = true;
}
