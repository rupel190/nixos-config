{ pkgs, lib, ... }:
let
  # young single-author app, written with heavy AI help (its README says so): pinned to a reviewed tag.
  # v1.22.2 fetches only Open-Meteo, Yahoo's chart endpoint and the RSS feeds in its config, and checks
  # for updates only when enabled; before bumping, read the diff for new hosts or spawned programs
  mirador = pkgs.rustPlatform.buildRustPackage {
    pname = "mirador";
    version = "1.22.2";
    src = pkgs.fetchFromGitHub {
      owner = "jchultarsky";
      repo = "mirador";
      tag = "v1.22.2"; # reviewed 2026-11-22
      hash = "sha256-YWdxv1gK/Q7hIr0uxT/cxGTB+gK3AuhoiWCy0HOA1OE=";
    };
    cargoHash = "sha256-+AO0/S5kinMBe++wyX3BTcHVuYxg2zw3sN3lc3dYbCs=";
    # the calendar tests convert between named zones; the build sandbox has no zone database
    preCheck = "export TZDIR=${pkgs.tzdata}/share/zoneinfo";
    meta = {
      description = "Personal terminal dashboard: clocks, calendar, weather, tasks, notes, markets";
      homepage = "https://github.com/jchultarsky/mirador";
      license = lib.licenses.mit;
      mainProgram = "mirador";
    };
  };
in
{
  home.packages = [ mirador ];

  # mirador saves its layout into config.toml, so the file stays its own; seeded once, with Vienna,
  # metric and Monday weeks in place of the shipped Boston, Fahrenheit and Sunday
  home.activation.miradorConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.config/mirador/config.toml"
    if [ ! -e "$f" ]; then
      mkdir -p "$(dirname "$f")"
      ${pkgs.gnused}/bin/sed \
        -e 's/^location\( *\)= "Boston, Massachusetts"/location\1= "Vienna, Austria"/' \
        -e 's/^units\( *\)= "imperial"/units\1= "metric"/' \
        -e 's/^week_starts = "sunday"/week_starts = "monday"/' \
        ${mirador.src}/assets/default_config.toml >"$f"
    fi
  '';
}
