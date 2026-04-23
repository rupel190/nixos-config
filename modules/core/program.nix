{ pkgs, lib, ... }:
{
  # dconf - Settings database for GTK applications
  # Allows GTK apps (virt-manager, file pickers, etc.) to save preferences
  # Without this, apps lose all settings on restart
  programs.dconf.enable = true;

  # System-wide program enables (user config in home-manager)
  programs.yazi.enable = true;
  programs.fish.enable = true;

  # Enable AppImage
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;

  # Gamescope: grant CAP_SYS_NICE for real-time thread priority
  # Without this, gamescope falls back to normal priority and warns "Performance will be affected"
  programs.gamescope.enable = true;
  programs.gamescope.capSysNice = true;

  # NOTE: nix-ld allows apps to use system libraries (e.g., Mason nvim plugin)
  # Currently using Nix packages instead, so this is disabled
  # programs.nix-ld.enable = true;
  # programs.nix-ld.libraries = with pkgs; [ ];
}
