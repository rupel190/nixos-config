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


  # Fix USB devices (mouse/keyboard) going to sleep - AGGRESSIVE FIX
  # Multiple layers of USB power management disabling
  boot.kernelParams = [
    "usbcore.autosuspend=-1"     # Disable USB autosuspend at kernel level
    "usb-storage.quirks=:u"      # Disable USB storage autosuspend
  ];

  # Disable USB autosuspend entirely via kernel module
  boot.extraModprobeConfig = ''
    options usbcore autosuspend=-1
  '';

  # Comprehensive udev rules to keep ALL USB devices awake
  services.udev.extraRules = ''
    # Disable autosuspend for all USB devices
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"

    # Disable autosuspend for USB input devices specifically
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", TEST=="power/control", ATTR{power/control}="on"

    # Keep USB HID devices (keyboards/mice) always on
    ACTION=="add", SUBSYSTEM=="hid", TEST=="../power/control", ATTR{../power/control}="on"

    # Disable runtime PM for all USB devices
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend_delay_ms", ATTR{power/autosuspend_delay_ms}="-1"

    # Arduino Micro handbrake (VID 2341, PID 8037) — tag as joystick + calibrate ABS_Z
    # EVDEV_ABS_02 format: min:max:resolution:fuzz:flat  (calibrated 2026-06-09: rest=2471, pull=63175)
    SUBSYSTEM=="input", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="8037", ENV{ID_INPUT_JOYSTICK}="1"
    SUBSYSTEM=="input", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="8037", ENV{EVDEV_ABS_02}="2471:63175:0:303:1821"
  '';

  # Keep swappiness low — prefer RAM over swap to avoid microstutters in games
  boot.kernel.sysctl."vm.swappiness" = 10;

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
