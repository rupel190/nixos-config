{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in
{
  # Note: Spotify unfree package is allowed via system-wide nixpkgs.config.allowUnfree in modules/core/system.nix

  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;

    enabledExtensions = with spicePkgs.extensions; [
      adblock
      hidePodcasts
      shuffle # shuffle+ (special characters are sanitized out of extension names)
    ];

    theme = spicePkgs.themes.catppuccin;
    colorScheme = "macchiato";
  };
}
