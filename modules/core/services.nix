{
  pkgs,
  lib,
  username,
  ...
}:
{
  services = {
    # PhotoPrism photo management
    mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ "photoprism" ];
      ensureUsers = [
        {
          name = "photoprism";
          ensurePermissions = {
            "photoprism.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    photoprism = {
      enable = true;
      originalsPath = "/home/${username}/Pictures";
      settings = {
        PHOTOPRISM_DATABASE_DRIVER = "mysql";
        PHOTOPRISM_DATABASE_DSN = "photoprism:@unix(/run/mysqld/mysqld.sock)/photoprism?charset=utf8mb4,utf8&parseTime=true";
        PHOTOPRISM_READONLY = "true";
        PHOTOPRISM_ADMIN_USER = "admin";
        PHOTOPRISM_ADMIN_PASSWORD = "insecure";
      };
    };
    gvfs.enable = true;
    udev = {
      enable = true;
      packages = [
        pkgs.libmtp # Android MTP connection
        pkgs.arduino # Arduino udev rules (covers SparkFun Pro Micro VIDs)
      ];
    };
    dbus.enable = true;

    xserver.videoDrivers = lib.mkForce [ "amdgpu" ];

    # SSD TRIM service (weekly optimization)
    fstrim.enable = true;

    # ZeroTier
    zerotierone = {
      enable = true;
    };

    # SSH server
    openssh = {
      enable = true;
      openFirewall = true;
      settings.PasswordAuthentication = false;
      settings.PermitRootLogin = "no";
    };
  };

  # ProtectHome=true makes /home an empty namespace — ReadWritePaths can't bind-mount into it.
  # PrivateUsers=true causes UID namespace conflicts with home dir access.
  systemd.services.photoprism.serviceConfig = {
    ProtectHome = lib.mkForce false;
    PrivateUsers = lib.mkForce false;
  };

  # NOTE: Uncomment for laptop - prevents shutdown on power button short-press
  # services.logind.extraConfig = ''
  #   HandlePowerKey=ignore
  # '';
}
