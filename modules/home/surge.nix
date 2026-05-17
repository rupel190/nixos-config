{ inputs, pkgs, ... }:
{
  home.packages = [ inputs.surge.packages.${pkgs.system}.default ];

  systemd.user.services.surge = {
    Unit = {
      Description = "Surge download manager daemon";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${inputs.surge.packages.${pkgs.system}.default}/bin/surge service __run";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  programs.fish.functions = {
    da = {
      description = "Download add - add URL from clipboard";
      body = ''
        surge add (wl-paste)
      '';
    };
    dl = {
      description = "Download list - open Surge TUI";
      body = ''
        surge
      '';
    };
  };
}
