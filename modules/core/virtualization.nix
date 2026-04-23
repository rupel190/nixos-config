{
  config,
  pkgs,
  username,
  ...
}:
{
  # Add user to libvirtd and docker groups
  users.users.${username}.extraGroups = [
    "libvirtd"
    "docker"
  ];

  # Install necessary packages
  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    virtio-win
    win-spice
    adwaita-icon-theme
  ];

  # Manage the virtualisation services
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
        # OVMF images are now available by default with QEMU
      };
    };
    spiceUSBRedirection.enable = true;
    docker.enable = true;
  };
  services.spice-vdagentd.enable = true;
}
