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

  # Logitech G29 - install oversteer udev rules for wheel control
  services.udev.packages = [ pkgs.oversteer ];

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

  fileSystems."/mnt/bak-ntfs" = {
    device = "/dev/disk/by-uuid/44FA3809FA37F5B0";
    fsType = "ntfs";
    options = [
      "defaults"
      "nofail"
    ];
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

  fileSystems."/mnt/bak-internal" = {
    device = "/dev/disk/by-uuid/6FFF-FCF9";
    fsType = "exfat";
    options = [
      "defaults"
      "nofail"
    ];
  };

  # Temporarily commented out due to systemd unit generation issue
  # fileSystems."/mnt/bak-external" = {
  #   device = "/dev/disk/by-uuid/1787c6c5-6ad8-4051-8d45-f61609e8c732";
  #   fsType = "ext4";
  #   options = [
  #     "defaults"
  #     "nofail"
  #     "x-systemd.automount"  # Use automount instead of regular mount
  #     "x-systemd.device-timeout=5"  # Wait only 5 seconds instead of 90
  #   ];
  # };

}
