{ inputs, pkgs, ... }:
let
  # Upstream vendorHash is stale; pass a fixed buildGoModule to patch it
  surge = pkgs.callPackage "${inputs.surge}/package.nix" {
    src = inputs.surge;
    version = "0.8.5";
    buildGoModule = args: pkgs.buildGoModule (args // {
      vendorHash = "sha256-5z4qZnbYEYhJ8mm/kBxhMDaVLxWfo/UKiXhtdoJTSZM=";
    });
  };
in
{
  home.packages = [ surge ];

  systemd.user.services.surge = {
    Unit = {
      Description = "Surge download manager daemon";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${surge}/bin/surge service __run";
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
