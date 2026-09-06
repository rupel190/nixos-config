# mycena — Microsoft Surface Book (1st gen, 2015), destined for the wall.
#
# Deliberately does NOT import ../../modules/core or ../../modules/home. Those
# describe workstations; this is a headless-ish panel that wants SSH and
# home-manager and nothing else. Two concrete reasons it MUST stay out of core:
#   - modules/core/bootloader.nix pins boot.kernelPackages to linuxPackages_latest,
#     which would override the linux-surface patched kernel below and kill touch.
#   - modules/core/secrets.nix declares agenix secrets this host has no need to
#     decrypt, and a missing .age file fails evaluation for the whole flake.
#
# Hardware confirmed over SSH from the live installer, 2026-09-06:
#   i5-6300U (Skylake, 2c/4t), 8 GiB RAM, Intel HD 520, NO discrete GPU
#   (PCIe root port 00:1c.0 enumerates the base but bus 01 is empty),
#   Samsung MZFLV256HCHP 238 GiB NVMe, Marvell 88W8897 wifi (mwifiex),
#   Intel iTouch/IPTS controller at 00:16.4.
{
  pkgs,
  inputs,
  username,
  host,
  ...
}:
let
  # Machines allowed in, both as the user and as root. amanita is the deploy
  # host, so its key is the one nixos-anywhere uses and every later
  # `--target-host root@mycena` rebuild depends on.
  # NOTE: amanita's ACTIVE key is ~/.ssh/id_ed25519_fresh, not ~/.ssh/id_ed25519
  # (the latter was rotated out and only still exists on disk). Because
  # id_ed25519_fresh is not one of ssh's default identity filenames, ssh will
  # NOT offer it automatically — deploys must pass -i, or name it in ~/.ssh/config.
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZWLYjYarb1rjAyhyfMsK1bH/uD7/V2e5rZN4/25xpY rupel@amanita" # deploy host
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9X3TOZAnn2UkKhDD0sKMpFBhDCc5T+mq3ARQh+LefK rupel@cordyceps"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFnj3eLieTvNxlFi+hCesV4gHJkx1CepEAu4/v0ZJc7o u0_a713@localhost" # phone (Termux)
  ];
in
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./wall.nix # phosh session, autologin, HiDPI — the wall-panel half
    ./homeassistant.nix # HA server on :8123; lift this out if it moves to a Pi

    # nixos-hardware has no Surface Book profile. The Book shares the Skylake
    # platform and the IPTS touch stack with the Pro 4 era, so this profile is
    # the correct fit; it pulls in ../common, which swaps boot.kernelPackages
    # for the linux-surface patched kernel (pinned 6.19.8, built from source —
    # nixos-hardware advertises no binary cache, so build this on amanita and
    # push the closure, never on the Surface itself).
    # It also enables iptsd (touch + stylus), thermald, and surface-control.
    inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel

    inputs.home-manager.nixosModules.home-manager
  ];

  # ── Hardware ────────────────────────────────────────────────────────────────
  # No hardware-configuration.nix: disko generates every fileSystems.* and
  # swapDevices entry from hosts/mycena/disko.nix, so only the bits disko does
  # not cover are stated here.
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "sdhci_pci" # SD reader in the base
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # 8 GiB of RAM on a machine that will occasionally be asked to do real work.
  # Complements the 8 GiB disk swap in disko.nix rather than replacing it.
  zramSwap.enable = true;

  # ── Boot ────────────────────────────────────────────────────────────────────
  # Secure Boot is off in firmware by choice, so plain systemd-boot, no
  # lanzaboote. The 1 GiB ESP leaves ample room, hence no configurationLimit
  # gymnastics.
  #
  # mem_sleep_default=deep is restated here on purpose. microsoft-surface-common
  # sets it as `mkDefault [ ... ]`, but boot.kernelParams also carries
  # normal-priority definitions from NixOS core (root=fstab, loglevel, lsm), and
  # priority filtering discards every lower-priority definition BEFORE list
  # merging — so upstream's value silently never reaches the kernel command
  # line. Verified: without this, evaluated params were
  # ["root=fstab","loglevel=4","lsm=landlock,yama,bpf"]. Declaring it at normal
  # priority makes it merge instead of lose.
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Network ─────────────────────────────────────────────────────────────────
  # Marvell 88W8897 is the only radio; it is known to drop under load and after
  # suspend. Wifi credentials are NOT in this repo — they are seeded into
  # /etc/NetworkManager/system-connections/ by nixos-anywhere --extra-files at
  # install time, so the PSK never enters git.
  networking = {
    hostName = host;
    networkmanager.enable = true;
    firewall.enable = true; # openssh opens 22 itself via openFirewall
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      # Key-only root, so `nixos-rebuild --target-host root@mycena` keeps working.
      PermitRootLogin = "prohibit-password";
    };
  };

  # ── Users ───────────────────────────────────────────────────────────────────
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "input"
      "surface-control" # performance-mode switching without sudo
    ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = sshKeys;
  };

  # Root keys matter here: nixos-anywhere installs over root, and every later
  # `nixos-rebuild --flake .#mycena --target-host root@...` needs them too.
  users.users.root.openssh.authorizedKeys.keys = sshKeys;

  programs.fish.enable = true; # login shell above needs the system-level enable

  # ── home-manager ────────────────────────────────────────────────────────────
  # Points at ./home.nix, NOT the repo-root home.nix — that one imports
  # modules/home, i.e. the entire Hyprland/AGS/Spotify desktop.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = { inherit inputs username host; };
    users.${username} = import ./home.nix;
  };

  # ── System ──────────────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [
      "root"
      username
    ];
  };
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    git
    wget
    vim
  ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # Frozen at the release this host was installed from (the 26.05 minimal ISO).
  # Never bump this.
  system.stateVersion = "26.05";
}
