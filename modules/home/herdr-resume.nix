{ config, pkgs, ... }:

# Resume Claude conversations after the herdr core restarts (reboot, crash). The core brings
# spaces, tabs and folders back but only as plain shells; this remembers each tab's session
# and types `claude --resume` (or `opencode --session`) into the recovered shell. See
# herdr-resume/herdr-resume.py. Also names herdr-app tabs after their agent's context
# (herdr-tabnames.py).
let
  herdr-resume = pkgs.writeShellScriptBin "herdr-resume" ''
    exec ${pkgs.python3}/bin/python3 ${./herdr-resume/herdr-resume.py} "$@"
  '';
  herdr-tabnames = pkgs.writeShellScriptBin "herdr-tabnames" ''
    exec ${pkgs.python3}/bin/python3 ${./herdr-resume/herdr-tabnames.py} "$@"
  '';
  path = "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
in
{
  home.packages = [
    herdr-resume
    herdr-tabnames
  ];

  systemd.user.services.herdr-resume = {
    Unit.Description = "Resume Claude sessions in recovered herdr terminals";
    Service = {
      ExecStart = "${herdr-resume}/bin/herdr-resume run";
      # hc comes from the profile; the claude session files are read from $HOME.
      Environment = path;
      Restart = "always";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.herdr-tabnames = {
    Unit.Description = "Name herdr-app tabs after their agent's context";
    Service = {
      ExecStart = "${herdr-tabnames}/bin/herdr-tabnames run";
      Environment = path;
      Restart = "always";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
