{
  pkgs,
  lib,
  config,
  host,
  ...
}:
let
  amanita = "10.0.0.20";
  pi = "10.0.0.10";
  router = "10.0.0.1";
  onAmanita = host == "amanita";
  at = top: left: height: width: { inherit top left height width; };

  # what gatus checks on amanita; urlcheck sends HEAD, which romm's health URL refuses (405)
  apps = [
    { port = 8096; path = "/health"; lan = true; } # jellyfin
    { port = 8989; path = "/ping"; lan = false; } # sonarr
    { port = 7878; path = "/ping"; lan = false; } # radarr
    { port = 9696; path = "/ping"; lan = false; } # prowlarr
    { port = 8085; path = "/api?mode=version"; lan = false; } # sabnzbd
    { port = 6767; path = "/"; lan = false; } # bazarr
    { port = 8070; path = "/"; lan = true; } # romm
    { port = 8083; path = "/"; lan = true; } # gatus
    { port = 8090; path = "/api/health"; lan = true; } # beszel
    { port = 8084; path = "/api/healthz"; lan = true; } # glance
  ];
  # amanita asks its apps on loopback; other machines only reach the ones open to the LAN
  appUrls = map (
    a: "http://${if onAmanita then "127.0.0.1" else amanita}:${toString a.port}${a.path}"
  ) (lib.filter (a: onAmanita || a.lan) apps);

  # the github module reads its token from the environment: borrow gh's login instead of storing another
  wtf = pkgs.writeShellScriptBin "wtf" ''
    WTF_GITHUB_TOKEN=$(${pkgs.gh}/bin/gh auth token 2>/dev/null || true) exec ${pkgs.wtfutil}/bin/wtfutil "$@"
  '';
in
{
  home.packages = [ wtf ];

  # One screen of WTF modules, a tab in kitty; every module is listed at https://wtfutil.com/modules/
  xdg.configFile."wtf/config.yml".source = (pkgs.formats.yaml { }).generate "wtf-config.yml" {
    wtf = {
      # negative sizes are shares of the window (tview), so the grid fits any tab width
      grid = {
        columns = [ (-1) (-1) (-1) ];
        rows = [ (-10) (-10) (-12) (-12) ];
      };
      refreshInterval = 1;
      mods = {
        resourceusage = {
          enabled = true;
          position = at 0 0 1 1;
          refreshInterval = 2;
          cpuCombined = true;
        };
        urlcheck = {
          title = "Services";
          enabled = true;
          position = at 0 1 2 1;
          refreshInterval = 60;
          timeout = 5;
          # urlcheck sends HEAD; splitpro's health URL refuses that (405), its manifest does not
          urls = appUrls ++ [
            "http://${pi}:8080/"
            "http://${pi}/"
            "http://${pi}:3000/manifest.json"
          ];
        };
        ping = {
          title = "Machines";
          enabled = true;
          position = at 0 2 1 1;
          refreshInterval = 30;
          hosts = [
            {
              label = "raspi";
              hostname = pi;
            }
            {
              label = "router";
              hostname = router;
            }
            (
              if onAmanita then
                {
                  label = "cordyceps";
                  hostname = "10.0.0.21";
                }
              else
                {
                  label = "amanita";
                  hostname = amanita;
                }
            )
            {
              label = "internet";
              hostname = "1.1.1.1";
            }
          ];
        };
        failedunits = {
          type = "cmdrunner";
          title = "Failed units";
          enabled = true;
          position = at 1 0 1 1;
          refreshInterval = 60;
          cmd = "panel-failed-units"; # dash-panels.nix
        };
        git = {
          enabled = true;
          position = at 2 0 2 1;
          refreshInterval = 30;
          commitCount = 6;
          repositories = [
            "${config.home.homeDirectory}/projects/nixos-config"
            "${config.home.homeDirectory}/projects/rupelxyz"
          ];
        };
        github = {
          enabled = true;
          position = at 2 1 2 1;
          refreshInterval = 300;
          username = "rupel190";
          repositories = [
            "rupel190/nixos-config"
            "rupel190/rupelxyz"
          ];
        };
        prettyweather = {
          title = "Vienna";
          enabled = true;
          position = at 2 2 1 1;
          refreshInterval = 1800;
          city = "Vienna";
          unit = "m";
          view = "0";
        };
        security = {
          type = "cmdrunner";
          title = "Security";
          enabled = true;
          position = at 3 2 1 1;
          refreshInterval = 300;
          cmd = "panel-security"; # dash-panels.nix
        };
      }
      # the laptop shows its battery where amanita shows what Spotify plays
      // (
        if onAmanita then
          {
            spotify = {
              enabled = true;
              position = at 1 2 1 1;
              refreshInterval = 2;
            };
          }
        else
          {
            power = {
              enabled = true;
              position = at 1 2 1 1;
              refreshInterval = 15;
            };
          }
      );
    };
  };
}
