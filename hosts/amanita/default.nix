{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  # Flatpak
  services.flatpak.enable = true;
  services.flatpak.packages = [
    "com.bambulab.BambuStudio"
  ];

  # Host-specific configuration
  networking.hostName = "amanita";

  # Headset - Razer Blacksomething v3 Pro
  hardware.openrazer.enable = true;
  hardware.openrazer.users = [ "rupel" ];

  # Gaming mice onboard config: DPI/polling/buttons (piper GUI, ratbagctl CLI)
  services.ratbagd.enable = true;

  # Logitech G29 wheel (oversteer) + Wooting keyboard hidraw access.
  # Must be packages, not extraRules: extraRules lands in 99-local.rules, but
  # systemd's 73-seat-late.rules is what turns TAG+="uaccess" into an ACL —
  # a tag set at 99 is never acted on. These install at priority 60/70.
  services.udev.packages = [
    pkgs.oversteer
    pkgs.wooting-udev-rules
  ];

  # Arduino handbrake - expose as joystick to SDL/BeamNG
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="8037", ENV{ID_INPUT_JOYSTICK}="1"
  '';

  # AMD + Wayland environment variables
  environment.variables = {
    EDITOR = "nvim";
    # Force discrete GPU (RX 9070 XT) -> Abiotic Factor would use iGPU otherwise
    # iGPU disabled in BIOS — DRI_PRIME=1 is invalid with only one GPU
    # DRI_PRIME = "1";
    # Use RADV (Mesa) driver for Vulkan
    AMD_VULKAN_ICD = "RADV";
    # Wayland specific
    WLR_RENDERER = "vulkan";
    # Disable shader cache issues
    MESA_SHADER_CACHE_DISABLE = "false";

    # Gaming optimizations for multi-monitor XWayland
    # Prevent games from locking to low FPS on monitor switches
    __GL_SYNC_DISPLAY_DEVICE = "DP-2"; # Prefer main monitor for OpenGL vsync
    DXVK_FRAME_RATE = "0"; # Disable DXVK frame limiting (let game/driver handle it)
    # AMD-specific performance variables
    RADV_PERFTEST = "nggc"; # Enable NGG culling for better performance
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Filesystems
  boot.supportedFilesystems = [
    "ntfs"
    "exfat"
  ];

  fileSystems."/mnt/silo" = {
    device = "/dev/disk/by-uuid/4eb8d0d5-60b4-424e-b7d9-4aeaba384849";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  };

  fileSystems."/mnt/gamedev" = {
    device = "/dev/disk/by-uuid/273504fb-eb69-448d-ba14-5472c43fdb8f";
    fsType = "ext4";
    options = [
      "noatime"
      "nodiratime"
      "nofail"
      "discard"
    ]; # SSD
  };

  fileSystems."/mnt/nvme950" = {
    device = "/dev/disk/by-uuid/836d4a09-5b71-46d1-9433-b52713b3cb14";
    fsType = "ext4";
    options = [
      "noatime"
      "nodiratime"
      "discard"
      "nofail" # Don't fail boot if drive is missing
    ]; # SSD
  };

  fileSystems."/mnt/supersilo" = {
    device = "/dev/disk/by-label/supersilo"; # 12TB HDD, ext4 made with -m 0
    fsType = "ext4";
    options = [
      "noatime"
      "nofail"
    ];
  };

  # Anything else (USB sticks, old drives on the SATA adapter) goes through udisks → /run/media/rupel

  # Disk health for every SATA + NVMe drive; warnings reach swaync the same way earlyoom's do
  services.smartd = {
    enable = true;
    # full checks, never wake a sleeping disk, short self-test Sundays 13:00, warn via systembus
    defaults.autodetected = "-a -n standby,q -s (S/../../7/13) -m <nomailer> -M exec ${
      pkgs.writeShellScript "smartd-notify" ''
        ${pkgs.dbus}/bin/dbus-send --system / net.nuetzlich.SystemNotifications.Notify \
          "string:Disk problem: $SMARTD_DEVICESTRING" "string:$SMARTD_MESSAGE"
      ''
    }";
    # the module's systembus option never adds -M exec on its own (it only checks mail/wall/x11)
    notifications = {
      wall.enable = false; # wall prints into every open terminal, TUIs included
      x11.enable = false;
    };
  };
  services.systembus-notify.enable = true;
}
