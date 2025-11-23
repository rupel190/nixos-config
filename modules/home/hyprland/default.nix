{ inputs, ... }:
{
  imports = [
    ./hyprland.nix
    ./config.nix
    ./keybinds.nix
    ./hyprlock.nix
    ./variables.nix
    ./workspaces.nix
    inputs.hyprland.homeManagerModules.default
  ];
}
