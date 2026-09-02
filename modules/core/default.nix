{
  inputs,
  lib,
  nixpkgs,
  self,
  username,
  host,
  ...
}:
{
  imports = [
    ./bootloader.nix
    ./greetd.nix
    ./hardware.nix
    ./xserver.nix
    ./network.nix
    ./nh.nix
    ./pipewire.nix
    ./program.nix
    ./secrets.nix
    ./security.nix
    ./services.nix
    ./steam.nix
    ./system.nix
    ./user.nix
    ./wayland.nix
    ./virtualization.nix
  ]
  # amanita only: 16 GB RX 9070 XT + the nvme950 model store.
  ++ lib.optionals (host == "amanita") [ ./comfyui.nix ];
}
