{ inputs, pkgs, ... }:
let
  version = "0.12.2";

  # Upstream's package.nix and flake.nix both lag the tags, so version and
  # vendorHash are pinned here and need bumping whenever the surge input moves.
  surge = pkgs.callPackage "${inputs.surge}/package.nix" {
    src = inputs.surge;
    inherit version;
    buildGoModule =
      args:
      pkgs.buildGoModule (
        args
        // {
          vendorHash = "sha256-Z1eNKci0MzXvKs49kOEYXr/JEO7AJB9kHdFTyNbxkw4=";
          # Upstream still stamps -X main.version=; the var lives in cmd.Version
          # since 0.12, so without this the binary reports "dev".
          ldflags = [
            "-s"
            "-w"
            "-X github.com/SurgeDM/Surge/cmd.Version=${version}"
          ];
        }
      );
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
