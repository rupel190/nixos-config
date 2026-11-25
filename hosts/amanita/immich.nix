{ lib, username, ... }:
{
  # Photo library at http://localhost:2283 (no LAN access): content search, faces, near-duplicates.
  # ~/Pictures is read as external libraries, added in the web UI; thumbnails and the phone's uploads go to /var/lib/immich.
  services.immich.enable = true;

  # a few hundred pictures are readable for the group only
  users.users.immich.extraGroups = [ "users" ];
  systemd.services.immich-server.serviceConfig = {
    ProtectHome = lib.mkForce "tmpfs"; # an empty /home with nothing in it but the pictures, read-only
    BindReadOnlyPaths = [ "/home/${username}/Pictures" ];
  };
  # the first scan takes hours on the CPU
  systemd.services.immich-machine-learning.serviceConfig.Nice = 15;
}
