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

  # Gamescope: grant CAP_SYS_NICE for real-time thread priority (works from terminal/non-Steam launches)
  programs.gamescope.enable = true;
  programs.gamescope.capSysNice = true;

  # gamescope-steam: wrapper that bypasses the NixOS setcap wrapper for Steam use.
  # Steam sets NoNewPrivs=1 + empty bounding set on itself, so the setcap wrapper's
  # capset() call fails and gamescope exits. Calling .gamescope-wrapped directly skips
  # that check; cap_sys_nice is a scheduling nicety, not required for functionality.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "gamescope-steam" ''
      exec ${pkgs.gamescope}/bin/.gamescope-wrapped "$@"
    '')
  ];

  # NOTE: nix-ld allows apps to use system libraries (e.g., Mason nvim plugin)
  # Currently using Nix packages instead, so this is disabled
  # programs.nix-ld.enable = true;
  # programs.nix-ld.libraries = with pkgs; [ ];
}
