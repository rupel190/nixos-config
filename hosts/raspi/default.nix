{
  lib,
  nixos-raspberrypi,
  username,
  ...
}:
{
  # Raspberry Pi 5, the always-on home server. Moving here from Debian: MIGRATION.md
  imports = with nixos-raspberrypi.nixosModules; [
    raspberry-pi-5.base
    # a bootable image: nix build .#nixosConfigurations.raspi.config.system.build.sdImage
    sd-image
    ../../modules/core/beszel-agent.nix
  ];

  # the image module offers zfs; nothing here uses it, and its module would be built for the Pi kernel
  boot.supportedFilesystems.zfs = lib.mkForce false;

  networking.hostName = "raspi";
  # the router's static lease gives this MAC 10.0.0.10
  networking.useDHCP = true;
  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "en_GB.UTF-8";

  # key-only logins, as on Debian: the three keys allowed there (their comments left out, one is an email)
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKo24m4/eIjKF+Rjv948UMSC53aoAN+GvCb+KLn4hhJ"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINWVsVoPRXMrm0enD8FK0KuCIjSsGTsQDoN8esZa9Xlh"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH5OvXGZRHhBIw+LyquzInWo2LFtgp8VXan0ZZ2EczCv"
    ];
  };
  security.sudo.wheelNeedsPassword = false;
  services.openssh = {
    enable = true;
    # the Debian host keys are copied onto the new medium before its first boot, so `ssh raspi` stays trusted
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  # amanita deploys here over ssh (nh os switch --target-host)
  nix.settings.trusted-users = [
    "root"
    username
  ];

  # apps, data and backups stay where Debian kept them
  fileSystems."/mnt/usbhdd" = {
    device = "/dev/disk/by-uuid/d2c9cf26-b12d-4074-b9b3-4a5d450e34d8";
    fsType = "ext4";
    options = [
      "noatime"
      "nofail"
      "x-systemd.device-timeout=10"
    ];
  };

  # identity and network membership ("raspi5", 192.168.196.27) are copied over from Debian before first boot
  services.zerotierone.enable = true;
  services.smartd.enable = true;
  virtualisation.docker.enable = true;

  system.stateVersion = "26.05";
}
