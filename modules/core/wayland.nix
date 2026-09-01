{ inputs, pkgs, ... }:
{
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  programs.hyprland = {
    enable = true;
    # The flake package + the damageMirrorsWith weakptr patch (overlay in system.nix).
    # This is the compositor greetd actually launches, via start-hyprland.
    package = pkgs.hyprland-mirrorfix;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config = {
      common.default = [ "gtk" ];
      hyprland.default = [
        "gtk"
        "hyprland"
      ];
    };
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}
