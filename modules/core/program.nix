{ pkgs, lib, ... }:
{
  # dconf - Settings database for GTK applications
  # Allows GTK apps (virt-manager, file pickers, etc.) to save preferences
  # Without this, apps lose all settings on restart
  programs.dconf.enable = true;

  # System-wide program enables (user config in home-manager)
  programs.yazi.enable = true;
  programs.fish.enable = true;

  # NOTE: nix-ld allows apps to use system libraries (e.g., Mason nvim plugin)
  # Currently using Nix packages instead, so this is disabled
  # programs.nix-ld.enable = true;
  # programs.nix-ld.libraries = with pkgs; [ ];
}
