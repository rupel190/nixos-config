{ config, ... }:
let
  pi = "10.0.0.10";
  router = "10.0.0.1";
  secret = config.age.secrets.health-dashboard;

  # once a minute; Discord hears about it after 3 misses in a row
  check = group: name: url: conditions: {
    inherit
      group
      name
      url
      conditions
      ;
    interval = "1m";
    alerts = [ { type = "discord"; } ];
  };
  ok = [ "[STATUS] == 200" ];
  ping = group: name: host: check group name "icmp://${host}" [ "[CONNECTED] == true" ];
  # asks Pi-hole directly, so it also catches "answers but stopped blocking"
  dns =
    name: query: condition:
    check "pi" name pi [ condition ]
    // {
      dns = {
        query-name = query;
        query-type = "A";
      };
    };
in
{
  # Health dashboard, here until the Pi runs NixOS; then this file moves to the Pi's host.
  # All open to the LAN: glance :8084 (front page), gatus :8083 (up/down + Discord), beszel :8090 (machines)
  imports = [ ./glance.nix ];

  # the Discord webhook and the Pi-hole app password; the HOMEPAGE_VAR_* names outlived Homepage.
  # Edit with `ragenix -e health-dashboard.age -i ~/.ssh/id_ed25519_fresh` inside secrets/
  age.secrets.health-dashboard.file = ../../secrets/health-dashboard.age;
  # an edited secret only reaches the apps through a restart
  systemd.services.gatus.restartTriggers = [ secret.file ];

  services.gatus = {
    enable = true;
    # no login; the page only shows up/down
    openFirewall = true;
    environmentFile = secret.path;
    settings = {
      web = {
        address = "0.0.0.0";
        port = 8083; # 8080 is too common a dev-server port
      };
      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };
      ui.title = "amanita health";
      # an empty webhook just switches alerts off; gatus logs "Ignoring provider=discord" and runs on
      alerting.discord = {
        webhook-url = "\${DISCORD_WEBHOOK_URL}";
        default-alert = {
          failure-threshold = 3;
          success-threshold = 2;
          send-on-resolved = true;
        };
      };
      endpoints = [
        (check "media" "jellyfin" "http://127.0.0.1:8096/health" (ok ++ [ "[BODY] == Healthy" ]))
        (check "media" "sonarr" "http://127.0.0.1:8989/ping" ok)
        (check "media" "radarr" "http://127.0.0.1:7878/ping" ok)
        (check "media" "prowlarr" "http://127.0.0.1:9696/ping" ok)
        (check "media" "bazarr" "http://127.0.0.1:6767/" ok)
        (check "media" "sabnzbd" "http://127.0.0.1:8085/api?mode=version" ok)
        (check "media" "romm" "http://127.0.0.1:8070/api/heartbeat" ok)

        (ping "pi" "pi" pi)
        (dns "pi-hole answers" "example.com" "[DNS_RCODE] == NOERROR")
        (dns "pi-hole blocks ads" "doubleclick.net" "[BODY] == 0.0.0.0")
        (check "pi" "pi-hole web" "http://${pi}:8080/admin/" ok)
        (check "pi" "invoiceninja" "http://${pi}/" ok)
        (check "pi" "splitpro" "http://${pi}:3000/api/healthz" ok)
        (check "pi" "paperless" "http://${pi}:8000/accounts/login/" ok)

        (ping "network" "router" router)
        (ping "network" "internet" "1.1.1.1")

        (check "dashboard" "beszel" "http://127.0.0.1:8090/api/health" ok)
        (check "dashboard" "glance" "http://127.0.0.1:8084/api/healthz" ok)
      ];
    };
  };

  # agents: modules/core/beszel-agent.nix on every NixOS machine, a container on the Pi
  services.beszel.hub = {
    enable = true;
    host = "0.0.0.0"; # has its own login
  };
  networking.firewall.allowedTCPPorts = [ config.services.beszel.hub.port ];
}
