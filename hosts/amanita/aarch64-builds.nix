{
  # amanita builds the Pi's NixOS (aarch64): whatever the caches lack runs here under qemu emulation
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
