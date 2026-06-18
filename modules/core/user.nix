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
    backupFileExtension = "bak";
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs username host; };
    users.${username} = import ./../../home.nix;
  };

  users.users.${username} = {
    isNormalUser = true;
    homeMode = "711"; # Allow service users (e.g. photoprism) to traverse home dir
    description = "${username}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "input" # Required for mouse/keyboard in Wayland
      "video" # Required for display management
      "seat" # Required for seat management
      "plugdev" # Required for Logitech HID++ device access (solaar)
      "dialout" # Required for serial port access (Arduino, USB-serial)
    ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      # cordyceps host
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9X3TOZAnn2UkKhDD0sKMpFBhDCc5T+mq3ARQh+LefK rupel@cordyceps"
    ];
  };
  nix.settings.allowed-users = [ "${username}" ];
}
