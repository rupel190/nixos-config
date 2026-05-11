{ inputs, ... }:
{
  imports = [
    ./hyprland.nix
    ./config.nix
    ./keybinds.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./variables.nix
    ./workspaces.nix
    inputs.hyprland.homeManagerModules.default
  ];
}
