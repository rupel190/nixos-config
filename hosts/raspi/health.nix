{ config, ... }:
let
  pi = "10.0.0.10";
  amanita = "10.0.0.20";
  router = "10.0.0.1";
  secret = config.age.secrets.health-dashboard;

  # once a minute, shown on the page only
  quiet = group: name: url: conditions: {
    inherit
      group
      name
      url
      conditions
      ;
    interval = "1m";
  };
  # Discord hears about it after 3 misses in a row
  check =
    group: name: url: conditions:
    quiet group name url conditions // { alerts = [ { type = "discord"; } ]; };
  ok = [ "[STATUS] == 200" ];
  connected = [ "[CONNECTED] == true" ];
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
  # Health dashboard on the always-on box: glance :8084 (front page), gatus :8083 (up/down + Discord).
  # Both open to the LAN without a login. The Beszel hub (machines) stays on amanita
  imports = [ ./glance.nix ];

  # the Discord webhook and the Pi-hole app password (for Glance); the HOMEPAGE_VAR_* names outlived Homepage.
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
        port = 8083;
      };
      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };
      ui.title = "home health";
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
        (dns "dns answers" "example.com" "[DNS_RCODE] == NOERROR")
        (dns "dns blocks ads" "doubleclick.net" "[BODY] == 0.0.0.0")
        (check "pi" "pihole web" "http://${pi}:8080/admin/" ok)
        (check "pi" "invoiceninja" "http://${pi}/" ok)
        (check "pi" "splitpro" "http://${pi}:3000/api/healthz" ok)
        (check "pi" "paperless" "http://${pi}:8000/accounts/login/" ok)
        (check "pi" "paperless-gpt" "http://127.0.0.1:8081/" ok)
        (check "pi" "glance" "http://127.0.0.1:8084/api/healthz" ok)

        (check "network" "router" "icmp://${router}" connected)
        (check "network" "internet" "icmp://1.1.1.1" connected)

        # amanita being off is normal, so no alerts; its *arr apps only listen on amanita itself
        (quiet "amanita" "amanita" "icmp://${amanita}" connected)
        (quiet "amanita" "jellyfin" "http://${amanita}:8096/health" (ok ++ [ "[BODY] == Healthy" ]))
        (quiet "amanita" "romm" "http://${amanita}:8070/api/heartbeat" ok)
        (quiet "amanita" "ollama" "http://${amanita}:11434/" ok)
        (quiet "amanita" "beszel" "http://${amanita}:8090/api/health" ok)
      ];
    };
  };

  # the database (a write every minute) on the USB disk. Ordered after it, not requiring it: with the disk gone,
  # Gatus still runs on the card and reports the apps that went with it
  fileSystems."/var/lib/private/gatus" = {
    device = "/mnt/usbhdd/apps/gatus";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
    depends = [ "/mnt/usbhdd" ];
  };
  systemd.services.gatus.after = [ "var-lib-private-gatus.mount" ];
}
