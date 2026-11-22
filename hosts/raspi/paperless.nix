{ inputs, pkgs, ... }:
let
  dir = "/mnt/usbhdd/apps/paperless";
  pkgsPaperless = inputs.nixpkgs-paperless.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  # Paperless natively, module and package from the nixpkgs-paperless input (3.5.1); 26.05's module is
  # written for 2.20. paperless-gpt stays a container (apps.nix, apps/paperless-gpt)
  disabledModules = [ "services/misc/paperless.nix" ];
  imports = [ "${inputs.nixpkgs-paperless}/nixos/modules/services/misc/paperless.nix" ];

  services.paperless = {
    enable = true;
    package = pkgsPaperless.paperless-ngx;
    address = "0.0.0.0";
    port = 8000;
    # the folders the docker setup used, so the data stays where it was
    dataDir = "${dir}/data/data";
    mediaDir = "${dir}/data/media";
    consumptionDir = "${dir}/data/consume";
    # PAPERLESS_SECRET_KEY, carried over from the docker .env. root:paperless 0640: paperless-manage (the
    # exporter, admin commands) reads it as the paperless user; tmpfiles refuses it under rupel's folder
    environmentFile = "${dir}/native.env";
    settings = {
      PAPERLESS_URL = "http://10.0.0.10:8000";
      PAPERLESS_TIME_ZONE = "Europe/Vienna";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ correspondent }}/{{ title }}";
    };
    # nightly export where the old backup.sh wrote it, a mirror with readable names; amanita pulls it at 03:45.
    # Paperless is stopped for the few seconds it runs
    exporter = {
      enable = true;
      directory = "/mnt/usbhdd/backups/paperless";
      onCalendar = "*-*-* 02:30:00";
      settings = {
        "no-progress-bar" = true;
        "no-color" = true;
        "compare-checksums" = true;
        "delete" = true;
        "use-filename-format" = true;
        "no-thumbnail" = true;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8000 ];
}
