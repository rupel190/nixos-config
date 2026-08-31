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

  # DDC/CI monitor control (ddcutil): loads i2c-dev and opens up /dev/i2c-*
  hardware.i2c.enable = true;


  # Fix USB devices (mouse/keyboard) going to sleep - AGGRESSIVE FIX
  # Multiple layers of USB power management disabling
  boot.kernelParams = [
    "usbcore.autosuspend=-1"     # Disable USB autosuspend at kernel level
    "usb-storage.quirks=:u"      # Disable USB storage autosuspend
  ];

  # Disable USB autosuspend entirely via kernel module
  boot.extraModprobeConfig = ''
    options usbcore autosuspend=-1

    # Novation Circuit Tracks pack uploads via Novation Components (WebMIDI in Chromium,
    # which speaks the ALSA *sequencer* API, so this is the seq pool — not snd_rawmidi).
    # The 4096 B kernel default is large enough for the SysEx device-inquiry handshake,
    # so Components *finds* the Tracks and then fails to send: a pack is megabytes.
    # Circuit firmware >1.02 widens this gap on purpose, sending bigger chunks to speed
    # transfers up, so being up to date makes it worse rather than better.
    # snd_seq_midi reads these in its probe path, so the port has to be re-created —
    # replug the device after changing them; a live write alone won't touch open ports.
    # Verified 2026-08-31: 4096 -> 65536 made a failing pack upload succeed immediately.
    options snd_seq_midi output_buffer_size=65536 input_buffer_size=65536
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

  # Out-of-memory handling: one *visible* guard instead of the silent, dormant
  # systemd-oomd (which sat idle through the 2026-07-02 Steam leak that drove free
  # RAM to 751 MiB — it only pressure-kills opted-in cgroups, not Hyprland-exec'd apps).
  # earlyoom SIGTERMs the biggest RAM hog *before* the desktop freezes in swap-thrash,
  # pops a desktop notification (so a kill is never a "mystery crash"), and logs every
  # kill to `journalctl -u earlyoom`.
  systemd.oomd.enable = false;
  services.earlyoom = {
    enable = true;
    # RAM-governed (a bit aggressive): earlyoom's condition is AND (mem AND swap both
    # low). With swappiness=10 we deliberately avoid swap, so waiting for swap to also
    # fill just prolongs thrash. Setting the swap gate to 100% (always true) drops it out
    # of the AND → RAM exhaustion alone triggers. Fires SIGTERM at <=5% RAM free (~3 GiB);
    # SIGKILL auto-derives to <=2.5%. This catches a leak (RAM gone, swap still free) that
    # the default <=10%-swap gate would have ignored (the 2026-07-02 Steam leak).
    freeMemThreshold = 5;
    freeSwapThreshold = 100;
    enableNotifications = true; # the anti-mystery switch: desktop toast on every kill
    extraArgs = [
      # Match earlyoom's 15-char /proc/comm as UNANCHORED substrings (NixOS wraps
      # binaries: `.Hyprland-wrapp`, `.Discord-wrappe`, `.zen-wrapped`).
      # Prefer disposable RAM hogs; never touch anything that would wreck the session.
      "--prefer"
      "steamwebhelper|chrome|firefox|zen|Discord|slack|electron|curseforge"
      "--avoid"
      "Hyprland|Xwayland|pipewire|wireplumber|sshd|systemd|dbus|greetd"
    ];
  };

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
