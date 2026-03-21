{
  config,
  pkgs,
  username,
  ...
}:
{
  # Add user to libvirtd group
  users.users.${username}.extraGroups = [ "libvirtd" ];

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
    # Wine
    wineWowPackages.stable
    winetricks
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

  };
  services.spice-vdagentd.enable = true;
}
