{ pkgs, ... }:
{
  # AMD Graphics Configuration
  hardware = {
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        mesa
        libva
        libva-utils
        # Attempt to improve RDNA 4 stability
        rocmPackages.clr.icd
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa
      ];
    };
  };
  # Improve stability
  hardware.enableRedistributableFirmware = true;

  # Fix USB devices (mouse/keyboard) going to sleep after reboot
  # Based on: https://discourse.nixos.org/t/external-mouse-and-keyboard-sleep/14900
  boot.kernelParams = [
    "usbcore.autosuspend=-1"  # Disable USB autosuspend (-1 = never suspend)
  ];

  # Force all USB devices to stay awake via udev rules
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
  '';

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };
}
