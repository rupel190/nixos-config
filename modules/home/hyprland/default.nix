{ inputs, ... }:
{
  imports = [
    ./hyprland.nix
    ./config.nix
    ./keybinds.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./hyprsunset.nix
    ./variables.nix
    ./workspaces.nix
    inputs.hyprland.homeManagerModules.default
  ];
}
