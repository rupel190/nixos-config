{ config, lib, ... }:
let
  amanita = "10.0.0.20";
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

  # Homepage tile for an app on amanita; keys come from the secret as HOMEPAGE_VAR_<NAME>_KEY.
  # The link opens `host`: localhost only works on amanita, its LAN address everywhere once the app's port is open
  tileOn = host: name: port: widget: {
    ${name} = {
      href = "http://${host}:${toString port}";
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
  tile = tileOn "localhost";
  lanTile = tileOn amanita;
in
{
  # Health dashboard, here until the Pi runs NixOS; then this file moves to the Pi's host.
  # All open to the LAN: homepage :8082 (front page), gatus :8083 (up/down + Discord), beszel :8090 (machines)
  imports = [ ./glance.nix ]; # :8084, on trial against homepage

  # tile API keys + the Discord webhook; edit with `ragenix -e health-dashboard.age` inside secrets/
  age.secrets.health-dashboard.file = ../../secrets/health-dashboard.age;
  # an edited secret only reaches the apps through a restart
  systemd.services.gatus.restartTriggers = [ secret.file ];
  systemd.services.homepage-dashboard.restartTriggers = [ secret.file ];

  services.homepage-dashboard = {
    enable = true;
    # open to the LAN like Jellyfin; no login, so anyone on the Wi-Fi sees it (keys stay server-side)
    openFirewall = true;
    allowedHosts = lib.concatMapStringsSep "," (h: "${h}:8082") [
      "localhost"
      "127.0.0.1"
      amanita
      "amanita"
      "amanita.lan"
    ];
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
          (lanTile "Gatus" 8083 { key = null; })
          (lanTile "Beszel" 8090 {
            key = null;
            username = "{{HOMEPAGE_VAR_BESZEL_USER}}";
            password = "{{HOMEPAGE_VAR_BESZEL_PASSWORD}}";
            version = 2;
          })
          (lanTile "Glance" 8084 null)
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
          (lanTile "Jellyfin" 8096 { enableBlocks = true; })
          (tile "Sonarr" 8989 { enableQueue = true; })
          (tile "Radarr" 7878 { enableQueue = true; })
          (tile "Prowlarr" 9696 { })
          (tile "SABnzbd" 8085 { })
          (tile "Bazarr" 6767 { })
          (lanTile "RomM" 8070 null)
        ];
      }
    ];
  };

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

        (ping "network" "router" router)
        (ping "network" "internet" "1.1.1.1")

        (check "dashboard" "homepage" "http://127.0.0.1:8082/" ok)
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
