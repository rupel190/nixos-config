{ inputs, ... }:
{
  imports = [
    ./hyprland.nix
    ./config.nix
    ./keybinds.nix
    ./hyprlock.nix
    ./variables.nix
    inputs.hyprland.homeManagerModules.default
  ];
}
