{ config, lib, ... }:
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

  # Homepage tile for a local app; keys come from the secret as HOMEPAGE_VAR_<NAME>_KEY
  tile = name: port: widget: {
    ${name} = {
      href = "http://localhost:${toString port}";
      icon = "${lib.toLower name}.svg";
      siteMonitor = "http://127.0.0.1:${toString port}";
    }
    // lib.optionalAttrs (widget != null) {
      # key = null drops the key for widgets that need none
      widget = lib.filterAttrs (_: v: v != null) (
        {
          type = lib.toLower name;
          url = "http://127.0.0.1:${toString port}";
          key = "{{HOMEPAGE_VAR_${lib.toUpper name}_KEY}}";
        }
        // widget
      );
    };
  };
in
{
  # Health dashboard, here until the Pi runs NixOS; then this file moves to the Pi's host.
  # All on localhost: homepage :8082 (front page), gatus :8083 (up/down + Discord), beszel :8090 (machines)
  imports = [ ./glance.nix ]; # :8084, on trial against homepage

  # tile API keys + the Discord webhook; edit with `ragenix -e health-dashboard.age` inside secrets/
  age.secrets.health-dashboard.file = ../../secrets/health-dashboard.age;
  # an edited secret only reaches the apps through a restart
  systemd.services.gatus.restartTriggers = [ secret.file ];
  systemd.services.homepage-dashboard.restartTriggers = [ secret.file ];

  services.homepage-dashboard = {
    enable = true;
    environmentFiles = [ secret.path ];
    settings = {
      title = "amanita";
      theme = "dark";
      color = "slate";
      headerStyle = "clean";
      layout = {
        Health = {
          style = "row";
          columns = 3;
        };
        Network = {
          style = "row";
          columns = 4;
        };
        Media = {
          style = "row";
          columns = 4;
        };
      };
    };
    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          cputemp = true;
          uptime = true;
          disk = [
            "/"
            "/mnt/silo"
          ];
        };
      }
      {
        datetime = {
          text_size = "md";
          format = {
            dateStyle = "long";
            timeStyle = "short";
            hour12 = false;
          };
        };
      }
    ];
    services = [
      {
        Health = [
          (tile "Gatus" 8083 { key = null; })
          (tile "Beszel" 8090 {
            key = null;
            username = "{{HOMEPAGE_VAR_BESZEL_USER}}";
            password = "{{HOMEPAGE_VAR_BESZEL_PASSWORD}}";
            version = 2;
          })
          (tile "Glance" 8084 null)
        ];
      }
      {
        Network = [
          {
            Pi-hole = {
              href = "http://${pi}:8080/admin";
              icon = "pi-hole.svg";
              widget = {
                type = "pihole";
                url = "http://${pi}:8080";
                version = 6;
                key = "{{HOMEPAGE_VAR_PIHOLE_KEY}}";
              };
            };
          }
          {
            InvoiceNinja = {
              href = "http://${pi}";
              icon = "invoice-ninja.svg";
              siteMonitor = "http://${pi}";
            };
          }
          {
            SplitPro = {
              # LAN only for now; login codes land in Mailpit at :8025
              href = "http://${pi}:3000";
              icon = "mdi-account-cash";
              siteMonitor = "http://${pi}:3000/api/healthz";
            };
          }
          {
            Router = {
              href = "https://${router}";
              icon = "openwrt.svg";
            };
          }
        ];
      }
      {
        Media = [
          (tile "Jellyfin" 8096 { enableBlocks = true; })
          (tile "Sonarr" 8989 { enableQueue = true; })
          (tile "Radarr" 7878 { enableQueue = true; })
          (tile "Prowlarr" 9696 { })
          (tile "SABnzbd" 8085 { })
          (tile "Bazarr" 6767 { })
          (tile "RomM" 8070 null)
        ];
      }
    ];
  };

  services.gatus = {
    enable = true;
    environmentFile = secret.path;
    settings = {
      web = {
        address = "127.0.0.1";
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

        (ping "network" "router" router)
        (ping "network" "internet" "1.1.1.1")

        (check "dashboard" "homepage" "http://127.0.0.1:8082/" ok)
        (check "dashboard" "beszel" "http://127.0.0.1:8090/api/health" ok)
        (check "dashboard" "glance" "http://127.0.0.1:8084/api/healthz" ok)
      ];
    };
  };

  services.beszel.hub.enable = true;
  # amanita's own agent; the hub reaches it on 127.0.0.1:45876, the firewall stays shut until the Pi hosts the hub
  services.beszel.agent = {
    enable = true;
    # the hub's public key from Add System; only the hub's private half can connect, so it's fine in the repo
    environment.KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPrLP1o+Zn4S0mz2CoesVkgmNi5/5HpXojgasEuZcsui";
  };
}
