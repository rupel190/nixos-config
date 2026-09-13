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

  # Gamescope. capSysNice stays false deliberately: the NixOS module's setcap wrapper
  # REPLACES the plain binary rather than adding to it (gamescope.nix has
  # environment.systemPackages = mkIf (!capSysNice) [ gamescope ]), and that wrapper
  # hard-exits on capset() under no_new_privs -- which is every Steam, Flatpak and
  # bwrap launch. All cap_sys_nice buys is realtime compositor thread priority
  # (without it: "No CAP_SYS_NICE, falling back to regular-priority compute and
  # threads"), which is not worth losing sandboxed use of gamescope entirely.
  programs.gamescope.enable = true;
  programs.gamescope.capSysNice = false;

  # NOTE: nix-ld allows apps to use system libraries (e.g., Mason nvim plugin)
  # Currently using Nix packages instead, so this is disabled
  # programs.nix-ld.enable = true;
  # programs.nix-ld.libraries = with pkgs; [ ];
}
