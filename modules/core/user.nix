{
  pkgs,
  inputs,
  username,
  host,
  ...
}:
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];
  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs username host; };
    users.${username} = import ./../../home.nix;
  };

  users.users.${username} = {
    isNormalUser = true;
    description = "${username}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input"       # Required for mouse/keyboard in Wayland
      "video"       # Required for display management
      "seat"        # Required for seat management
    ];
    shell = pkgs.fish;
  };
  nix.settings.allowed-users = [ "${username}" ];
}
