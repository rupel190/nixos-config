{ config, lib, pkgs, ... }:
let
  router = "10.0.0.1";
  data = "/mnt/usbhdd/apps/pihole";
in
{
  # Pi-hole tells devices apart although every lookup comes through the router: the router attaches the
  # asking device's address (dnsmasq add-subnet) and Pi-hole counts it as the client (dns.EDNS0ECS, a default).
  # AdGuard Home only logs that address, so it saw one client, the router, and went again
  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    openFirewallWebserver = true;
    # No `lists`: the module adds them through the API on every start and fails from the second on (UNIQUE
    # constraint). The StevenBlack list lives in Pi-hole's own database, as on Debian
    settings = {
      dns = {
        upstreams = [
          "1.1.1.1"
          "2606:4700:4700::1111"
          "2620:119:53::53"
          "208.67.220.220"
        ];
        # local names and reverse lookups from the router
        revServers = [
          "true,10.0.0.0/24,${router},lan"
          "true,fdaf:5034:9b4e::/48,${router},lan"
          "true,10.0.100.0/24,${router},lan"
        ];
        listeningMode = "ALL";
      };
    };
  };
  # Pi-hole's old port: http://10.0.0.10:8080/admin
  services.pihole-web = {
    enable = true;
    ports = [ { port = 8080; } ];
  };

  # The settings file is read-only from Nix, so the login and Glance's app password (hashes) come from here
  systemd.services.pihole-ftl.serviceConfig.EnvironmentFile = "${data}/ftl.env";
  systemd.services.pihole-ftl.unitConfig.RequiresMountsFor = "/var/lib/pihole";

  # the weekly list refresh Pi-hole's own cron did; the module has none
  systemd.services.pihole-gravity = {
    description = "Refresh Pi-hole's blocklists";
    after = [
      "network-online.target"
      "pihole-ftl.service"
    ];
    requires = [ "network-online.target" ];
    path = [
      pkgs.procps
      pkgs.systemd
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "pihole";
      Group = "pihole";
    };
    # the rebuild swaps gravity.db under FTL, which keeps reading the old file until told to reopen it
    script = ''
      ${lib.getExe config.services.pihole-ftl.piholePackage} -g
      kill -s SIGRTMIN "$(systemctl show --property MainPID --value pihole-ftl.service)"
    '';
  };
  systemd.timers.pihole-gravity = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 04:00";
      Persistent = true;
    };
  };

  # history and devices on the USB disk, like every app's data
  fileSystems."/var/lib/pihole" = {
    device = data;
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
    depends = [ "/mnt/usbhdd" ];
  };
}
