{ config, lib, ... }:
let
  amanita = "10.0.0.20";
  pi = "10.0.0.10";
  router = "10.0.0.1";
  secret = config.age.secrets.health-dashboard;

  # monitor row: the link opens `url`, the dot comes from `check`
  site = title: icon: url: check: {
    inherit title icon url;
    check-url = check;
  };
  # an app on amanita; same health paths as the gatus checks. The link opens `host`:
  # localhost only works on amanita, its LAN address everywhere once the app's port is open
  app =
    host: title: port: path:
    site title "di:${lib.toLower title}" "http://${host}:${toString port}" "http://127.0.0.1:${toString port}${path}";
  local = app "localhost";
  lan = app amanita;
  monitor = title: sites: {
    type = "monitor";
    cache = "1m";
    inherit title sites;
  };
in
{
  # Glance on :8084, the front page (it won over Homepage)
  services.glance = {
    enable = true;
    # the Pi-hole app password, still under the name Homepage gave it
    environmentFile = secret.path;
    # open to the LAN like Jellyfin; no login, so anyone on the Wi-Fi sees it
    openFirewall = true;
    settings = {
      server = {
        host = "0.0.0.0";
        port = 8084;
      };
      # catppuccin macchiato, like btop
      theme = {
        background-color = "232 23 18";
        contrast-multiplier = 1.2;
        primary-color = "220 83 75";
        positive-color = "105 48 72";
        negative-color = "351 74 73";
      };
      pages = [
        {
          # one tab for everything; a tab per machine needs Glance's own agent on that machine
          name = "Home";
          columns = [
            {
              size = "small";
              widgets = [
                {
                  type = "clock";
                  hour-format = "24h";
                }
                {
                  type = "calendar";
                  first-day-of-week = "monday";
                }
                {
                  type = "weather";
                  location = "Vienna, Austria";
                  hour-format = "24h";
                }
              ];
            }
            {
              size = "full";
              widgets = [
                {
                  type = "server-stats";
                  servers = [
                    {
                      type = "local";
                      name = "amanita";
                      hide-mountpoints-by-default = true;
                      mountpoints = {
                        "/".name = "root";
                        "/mnt/silo".name = "silo";
                      };
                    }
                  ];
                }
                (monitor "Media" [
                  (lan "Jellyfin" 8096 "/health")
                  (local "Sonarr" 8989 "/ping")
                  (local "Radarr" 7878 "/ping")
                  (local "Prowlarr" 9696 "/ping")
                  (local "SABnzbd" 8085 "/api?mode=version")
                  (local "Bazarr" 6767 "/")
                  (lan "RomM" 8070 "/api/heartbeat")
                ])
                (monitor "Pi and network" [
                  (site "Pi-hole" "di:pi-hole" "http://${pi}:8080/admin" "http://${pi}:8080/admin/")
                  (site "InvoiceNinja" "di:invoice-ninja" "http://${pi}" "http://${pi}/")
                  (site "SplitPro" "mdi:account-cash" "http://${pi}:3000" "http://${pi}:3000/api/healthz")
                  (site "Paperless" "di:paperless-ngx" "http://${pi}:8000" "http://${pi}:8000/accounts/login/")
                  (site "Mailpit" "mdi:email-outline" "http://${pi}:8025" "http://${pi}:8025/")
                  (
                    site "Router" "di:openwrt" "https://${router}" "https://${router}/"
                    # LuCI's certificate is self-signed
                    // {
                      allow-insecure = true;
                    }
                  )
                ])
                {
                  type = "dns-stats";
                  service = "pihole-v6";
                  url = "http://${pi}:8080";
                  password = "\${HOMEPAGE_VAR_PIHOLE_KEY}";
                  hour-format = "24h";
                }
              ];
            }
            {
              size = "small";
              widgets = [
                (monitor "Dashboards" [
                  (lan "Gatus" 8083 "/")
                  (lan "Beszel" 8090 "/api/health")
                ])
                {
                  type = "releases";
                  show-source-icon = true;
                  repositories = [
                    "henrygd/beszel"
                    "TwiN/gatus"
                    "glanceapp/glance"
                    "oss-apps/split-pro"
                    "jellyfin/jellyfin"
                    "pi-hole/pi-hole"
                    "invoiceninja/invoiceninja"
                  ];
                }
              ];
            }
          ];
        }
      ];
    };
  };
  systemd.services.glance.restartTriggers = [ secret.file ];
}
