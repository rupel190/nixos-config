{ lib, username, ... }:
let
  root = "/mnt/silo/media";
in
{
  # Shared group: radarr files movies, bazarr writes subtitles next to them, you browse them
  users.groups.media = { };
  users.users.${username}.extraGroups = [ "media" ];

  # setgid dirs so everything created inside stays group media
  systemd.tmpfiles.rules = [
    "d ${root}        2775 ${username} media - -"
    "d ${root}/movies 2775 ${username} media - -"
    "d ${root}/tv     2775 ${username} media - -"
    "d ${root}/usenet 2775 ${username} media - -"
    # sabnzbd creates these 0700 on its own, which would lock radarr/sonarr out of finished downloads
    "d ${root}/usenet/incomplete 2775 sabnzbd media - -"
    "d ${root}/usenet/complete   2775 sabnzbd media - -"
  ];

  # Web UIs stay on localhost (firewall closed): radarr :7878, sonarr :8989, prowlarr :9696, bazarr :6767, sabnzbd :8085
  services.radarr = {
    enable = true;
    group = "media";
  };
  services.sonarr = {
    enable = true;
    group = "media";
  };
  services.prowlarr.enable = true;
  # Usenet download client; servers/credentials are entered in its web UI (config stays writable)
  services.sabnzbd = {
    enable = true;
    group = "media";
    configFile = null; # stateVersion < 26.05 defaults to a legacy ini path that silently ignores settings
    settings.misc = {
      port = 8085; # 8080 is too common a dev-server port
      download_dir = "${root}/usenet/incomplete";
      complete_dir = "${root}/usenet/complete"; # same fs as the library: imports are instant renames
      permissions = "775"; # finished job folders group-readable for radarr/sonarr
    };
  };
  services.bazarr = {
    enable = true;
    group = "media";
  };

  # :8096, open on the LAN so TV/phone can stream; reads the library via group media
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    hardwareAcceleration = {
      enable = true;
      type = "vaapi"; # RX 9070 XT via Mesa
      device = "/dev/dri/renderD128";
    };
  };
  users.users.jellyfin.extraGroups = [ "media" ];
  systemd.services.jellyfin.unitConfig.RequiresMountsFor = root;

  # group-writable files so bazarr can add subtitles; wait for the nofail silo mount
  systemd.services.radarr = {
    serviceConfig.UMask = lib.mkForce "0002"; # module hardcodes 0022
    unitConfig.RequiresMountsFor = root;
  };
  systemd.services.sonarr = {
    serviceConfig.UMask = lib.mkForce "0002";
    unitConfig.RequiresMountsFor = root;
  };
  systemd.services.sabnzbd = {
    serviceConfig.UMask = "0002";
    unitConfig.RequiresMountsFor = root;
  };
  systemd.services.bazarr = {
    serviceConfig.UMask = "0002";
    unitConfig.RequiresMountsFor = root;
  };
}
