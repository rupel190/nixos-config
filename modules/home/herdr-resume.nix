{ config, pkgs, ... }:

# Resume Claude conversations after the herdr core restarts (reboot, crash). The core brings
# spaces, tabs and folders back but only as plain shells; this remembers each tab's session
# and types `claude --resume` into the recovered shell. See herdr-resume/herdr-resume.py.
let
  herdr-resume = pkgs.writeShellScriptBin "herdr-resume" ''
    exec ${pkgs.python3}/bin/python3 ${./herdr-resume/herdr-resume.py} "$@"
  '';
in
{
  home.packages = [ herdr-resume ];

  systemd.user.services.herdr-resume = {
    Unit.Description = "Resume Claude sessions in recovered herdr terminals";
    Service = {
      ExecStart = "${herdr-resume}/bin/herdr-resume run";
      # hc comes from the profile; the claude session files are read from $HOME.
      Environment = "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
      Restart = "always";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
