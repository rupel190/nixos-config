{ config, lib, ... }:
let
  pi = "10.0.0.10";
  router = "10.0.0.1";
  secret = config.age.secrets.health-dashboard;

  # monitor row: the link opens `url`, the dot comes from `check`
  site = title: icon: url: check: {
    inherit title icon url;
    check-url = check;
  };
  # an app on amanita; same health paths as the gatus checks
  local =
    title: port: path:
    site title "di:${lib.toLower title}" "http://localhost:${toString port}" "http://127.0.0.1:${toString port}${path}";
  monitor = title: sites: {
    type = "monitor";
    cache = "1m";
    inherit title sites;
  };
in
{
  # Glance on :8084, side by side with Homepage (:8082) until one of them goes; drop this import in health.nix to remove it
  services.glance = {
    enable = true;
    # reuses Homepage's Pi-hole app password from the same secret
    environmentFile = secret.path;
    settings = {
      server.port = 8084;
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
          name = "amanita";
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
                  (local "Jellyfin" 8096 "/health")
                  (local "Sonarr" 8989 "/ping")
                  (local "Radarr" 7878 "/ping")
                  (local "Prowlarr" 9696 "/ping")
                  (local "SABnzbd" 8085 "/api?mode=version")
                  (local "Bazarr" 6767 "/")
                  (local "RomM" 8070 "/api/heartbeat")
                ])
                (monitor "Pi and network" [
                  (site "Pi-hole" "di:pi-hole" "http://${pi}:8080/admin" "http://${pi}:8080/admin/")
                  (site "InvoiceNinja" "di:invoice-ninja" "http://${pi}" "http://${pi}/")
                  (site "SplitPro" "mdi:account-cash" "http://${pi}:3000" "http://${pi}:3000/api/healthz")
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
                  (local "Homepage" 8082 "/")
                  (local "Gatus" 8083 "/")
                  (local "Beszel" 8090 "/api/health")
                ])
                {
                  type = "releases";
                  show-source-icon = true;
                  repositories = [
                    "henrygd/beszel"
                    "TwiN/gatus"
                    "glanceapp/glance"
                    "gethomepage/homepage"
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
