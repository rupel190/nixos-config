{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../modules/core
  ];

  # Host-specific configuration
  networking.hostName = "amanita";

  # AMD + Wayland environment variables
  environment.variables = {
    EDITOR = "nvim";
    # Force discrete GPU (RX 9070 XT) -> Abiotic Factor would use iGPU otherwise
    DRI_PRIME = "1";
    # Use RADV (Mesa) driver for Vulkan
    AMD_VULKAN_ICD = "RADV";
    # Wayland specific
    WLR_RENDERER = "vulkan";
    # Disable shader cache issues
    MESA_SHADER_CACHE_DISABLE = "false";
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

  fileSystems."/mnt/bak-btrfs" = {
    device = "/dev/disk/by-uuid/2cf4acdd-ebf1-4134-8225-80b7982f68f7";
    fsType = "btrfs";
    options = [
      "noatime"
      "compress=zstd"
      "discard=async"
    ]; # SSD + btrfs-specific optimizations
  };

  fileSystems."/mnt/bak-internal" = {
    device = "/dev/disk/by-uuid/6FFF-FCF9";
    fsType = "exfat";
    options = [
      "defaults"
      "nofail"
    ];
  };

  fileSystems."/mnt/bak-external" = {
    device = "/dev/disk/by-uuid/1787c6c5-6ad8-4051-8d45-f61609e8c732";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  };

}
