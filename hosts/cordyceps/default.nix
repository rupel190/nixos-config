{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  # Flatpak. The Bambu Studio launchers in modules/home (desktop entry, fish
  # alias, yazi opener) are unconditional, so any host importing modules/home
  # needs the Flatpak they point at or they're dead commands.
  services.flatpak.enable = true;
  services.flatpak.packages = [
    "com.bambulab.BambuStudio"
  ];

  # Host-specific configuration
  networking.hostName = "cordyceps";

  # Firmware updates via LVFS (needed for BIOS >= 4.02, which enables the
  # official FW13 touch panel). Run: fwupdmgr refresh --force && fwupdmgr update
  services.fwupd.enable = true;

  # Allied Vision Alvium 1800 U-507c (USB3 Vision) through Aravis, the vendor-neutral GenICam
  # library: `arv-tool-0.8` lists the camera, `arv-viewer-0.8` is the live view (focus, aperture).
  # No proprietary Vimba X needed. Aravis ships no udev rules, so access is granted here.
  environment.systemPackages = [ pkgs.aravis ];
  # uaccess must ship as a udev *package* (70-*), as for the P-touch in modules/core/printing.nix.
  # ⚠️ vendor id 1ab2 (Allied Vision) is from memory: confirm with `lsusb` once it is plugged in.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "alvium-udev-rules";
      destination = "/lib/udev/rules.d/70-alvium.rules";
      text = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="1ab2", TAG+="uaccess"
      '';
    })
  ];
  # USB3 Vision streams need more USB buffer than the 16 MB default, or full-resolution frames drop.
  boot.kernelParams = [ "usbcore.usbfs_memory_mb=1000" ];

  # Laptop-specific settings
  # services.logind.extraConfig = ''
  #   # Don't shutdown when power button is short-pressed (useful for laptops)
  #   HandlePowerKey=ignore
  # '';
  #
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
