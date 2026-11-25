{ pkgs, lib, ... }:

# gitview (github.com/ChmaraX/herdr-gitview): the repo's changes in herdr-app's Changes panel,
# with a diff pane beside it that Enter turns into nvim. traveler-side puts it there
# (herdr-traveler-side.nix); its install.sh would edit keys.json and the layout, both links here.
# Reviewed at v0.6.0: no network; runs git, hc, herdr-app and the editor.
let
  version = "0.6.0";
  src = pkgs.fetchFromGitHub {
    owner = "ChmaraX";
    repo = "herdr-gitview";
    rev = "v${version}";
    hash = "sha256-TMNepzANCA0YWphvN0hFt+f/bOgdjqYppBzUF/aq+x4=";
  };

  gitview = pkgs.rustPlatform.buildRustPackage {
    pname = "herdr-gitview";
    inherit version src;
    cargoHash = "sha256-ZY0z2ajY/OCbCyqQH2HlWMmtyflOfSDQXRPQNEpFYpY=";
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.oniguruma ];
    env.RUSTONIG_SYSTEM_LIBONIG = true;
    nativeCheckInputs = [ pkgs.git ];
    # the tests' stand-in programs; the sandbox has neither path
    preCheck = ''
      substituteInPlace tests/*.rs \
        --replace-quiet '#!/bin/bash' '#!${pkgs.bash}/bin/bash' \
        --replace-quiet '#!/usr/bin/env python3' '#!${pkgs.python3}/bin/python3'
    '';
    meta.mainProgram = "herdr-gitview";
  };

  # install.sh's copy step (-L: files the mods share are links in the repo); the image cache
  # goes to the app's data folder, as the mod folders are read-only here
  mods = pkgs.runCommand "herdr-gitview-mods" { } ''
    cp -rL ${src}/herdr-app/mods $out
    chmod -R u+w $out
    substituteInPlace $out/gitview-diff/preview.js \
      --replace-fail '"mods/gitview-diff/.cache"' '"data/gitview/cache"'
    # herdr-gitview#27: nvim and the diff swap places in a split, which halves them if it is to the right
    substituteInPlace $out/*/nvim.js \
      --replace-fail 'file], folder: o.root, place: "right"' 'file], folder: o.root, place: replace ? "down" : "right"'
    substituteInPlace $out/gitview/main.js \
      --replace-fail 'run("pane.split", { direction: "right", pane, mod: "gitview-diff"' 'run("pane.split", { direction: "down", pane, mod: "gitview-diff"'
    cat > $out/gitview/config.json <<'JSON'
    ${builtins.toJSON {
      bin = lib.getExe gitview;
      herdr_app = "herdr-app";
      hc = "hc";
    }}
    JSON
  '';
in
{
  xdg.configFile = lib.genAttrs (map (m: "herdr-app/mods/${m}") [
    "gitview"
    "gitview-agents"
    "gitview-ask"
    "gitview-diff"
    "gitview-keys"
    "gitview-mark"
    "gitview-sidebar"
    "gitview-tab"
    "gitview-tracing"
  ]) (n: { source = "${mods}/${baseNameOf n}"; });
}
