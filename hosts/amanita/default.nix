{ pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./media.nix
    ./health.nix
    ./ollama-pi.nix
    ./aarch64-builds.nix
    ./../../modules/core
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  # Flatpak
  services.flatpak.enable = true;
  services.flatpak.packages = [
    "com.bambulab.BambuStudio"
    "io.exodus.Exodus" # nixpkgs exodus is requireFile pinned to an old zip; Flathub tracks upstream
    "com.overwolf.curseforge" # registers curseforge:// and cfauth:// itself; the AppImage has no handlers
  ];
  # Sandbox only gets ~/Documents/curseforge by default; WoW lives in its Steam prefix, Hytale in its own Flatpak's data
  services.flatpak.overrides.settings."com.overwolf.curseforge".Context.filesystems = [
    "~/.local/share/Steam/steamapps/compatdata/3728983471/pfx/drive_c/Program Files (x86)/World of Warcraft"
    "~/.var/app/com.hypixel.HytaleLauncher/data/Hytale"
  ];

  # Host-specific configuration
  networking.hostName = "amanita";

  # Local LLMs for opencode. Module defaults keep it on 127.0.0.1 with the firewall closed.
  services.ollama = {
    enable = true;
    package = inputs.nixpkgs-ollama.legacyPackages.${pkgs.stdenv.hostPlatform.system}.ollama-rocm;
    # Ollama's default context silently truncates opencode's system prompt + tool schemas.
    # Sized so the fast model's weights + KV cache stay inside 16 GB VRAM.
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "32768";
      # opencode lists every pulled model; a :cloud one would ship prompts and files off-box.
      OLLAMA_NO_CLOUD = "1";
    };
  };

  # Compressed swap in RAM ahead of the disk partition (zram priority 5 > partition's -1).
  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

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

  # Steam Frame sideloading: APKs go to the Lepton container via `adb connect frame:5555` (Wi-Fi; USB reaches SteamOS, not Android)
  environment.systemPackages = [
    pkgs.android-tools
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

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/4eb8d0d5-60b4-424e-b7d9-4aeaba384849";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
    ];
  };

  fileSystems."/mnt/games" = {
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

  fileSystems."/mnt/silo" = {
    device = "/dev/disk/by-uuid/3114d20f-90c3-4e1c-9fb1-a382889f446e"; # 12TB HDD, ext4 made with -m 0
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
