{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
  ];

  # Host-specific configuration
  networking.hostName = "cordyceps";

  # Laptop-specific settings
  services.logind.extraConfig = ''
    # Don't shutdown when power button is short-pressed (useful for laptops)
    HandlePowerKey=ignore
  '';

  # Laptop power management
  services.tlp = {
    enable = true;
    settings = {
      # Battery conservation
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # Laptop monitor configuration (for Hyprland)
  # This will be available as a home-manager module when cordyceps is set up
  # Monitor: eDP-1 (laptop display), 2880x1920@120Hz
  # Uncomment when setting up cordyceps:
  # wayland.windowManager.hyprland.settings.monitor = [
  #   "eDP-1, 2880x1920@120.00000, 0x0, 1"
  # ];

  # NOTE: Add your laptop's filesystems here when you set it up
  # boot.supportedFilesystems = [ "ntfs" "exfat" ];
  # fileSystems."/mnt/backup" = { ... };
}
