{
  # amanita builds the Pi's NixOS (aarch64): whatever the caches lack runs here under qemu emulation
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # nixos-raspberrypi's cache has the Pi kernel and firmware prebuilt. Only builds that ask for it use it
  # (--option extra-substituters https://nixos-raspberrypi.cachix.org); amanita's own builds never do
  nix.settings = {
    trusted-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };
}
