{ pkgs, lib, ... }:
let
  # Which checkouts a machine is expected to have under ~/projects. Nix owns
  # this LIST; projects-sync does the cloning, on demand, never at activation.
  #
  # URLs are matched EXACTLY against `git remote get-url origin`. That strictness
  # is the point: an ssh-vs-https mismatch is how one repo quietly becomes two
  # checkouts with divergent work, which is exactly what happened to
  # claude-interaction-tests (2026-09-15).
  #
  # ⛔ Deliberately absent: recustomize/* and rieder/*. 56 of the 57 GB under
  # ~/projects is those two, almost all of it model weights, venvs and test
  # output that is machine-specific and must not travel. Clone them by hand on a
  # machine that actually needs them.
  projects = {
    "nixos-config" = "git@github.com:rupel190/nixos-config.git";
    "interaction-tests" = "git@github.com:rupel190/claude-interaction-tests.git";
    "rupelxyz" = "git@github.com:rupel190/rupelxyz";
    "singify" = "git@github.com:rupel190/singify.git";
    "song-analyzer" = "git@github.com:rupel190/song-analyzer.git";
    "cstheskin" = "git@github.com:rupel190/cstheskin.git";
    "wezterm-image-mcp" = "git@github.com:rupel190/wezterm-image-mcp.git";
    "wow-baganator-plus" = "git@github.com:rupel190/wow-baganator-plus.git";

    # Nested paths work too, e.g.:
    # "obsidian/tubs-renderer" = "git@github.com:rupel190/tubs-renderer.git";
  };

  manifest = pkgs.writeText "projects-manifest" (
    lib.concatStringsSep "\n" (lib.mapAttrsToList (rel: url: "${rel}\t${url}") projects) + "\n"
  );
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "projects-sync";
      runtimeInputs = with pkgs; [
        git
        coreutils
      ];
      bashOptions = [
        "nounset"
        "pipefail"
      ];
      text = ''
        MANIFEST=${manifest}
        ${builtins.readFile ./projects-sync.sh}
      '';
    })

    (pkgs.writeShellApplication {
      name = "projects-status";
      runtimeInputs = with pkgs; [
        git
        fd
        coreutils
      ];
      bashOptions = [
        "nounset"
        "pipefail"
      ];
      text = builtins.readFile ./projects-status.sh;
    })
  ];
}
