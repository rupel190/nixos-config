{
  pkgs,
  lib,
  host,
  ...
}:
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

  # any command's output as a mirador panel (external-panel protocol v1)
  run = pkgs.writers.writePython3Bin "mirador-run" { flakeIgnore = [ "E501" ]; } (
    builtins.readFile ./mirador-run.py
  );

  # the panels from dash-panels.nix; mirador finds both commands on PATH
  panels = [
    {
      id = "health";
      title = "Health";
      every = 30;
      command = "panel-health";
    }
  ]
  # the backup jobs and /mnt/backup only exist on amanita
  ++ lib.optional (host == "amanita") {
    id = "backups";
    title = "Backups";
    every = 300;
    command = "panel-backups";
  }
  ++ [
    {
      id = "failed-units";
      title = "Failed units";
      every = 60;
      command = "panel-failed-units";
    }
    {
      id = "security";
      title = "Security";
      every = 300;
      command = "panel-security";
    }
  ];
  pluginBlock = pkgs.writeText "mirador-plugins.toml" (
    "# >>> nix: external panels, rewritten on every switch (modules/home/mirador.nix); place them with w\n"
    + lib.concatMapStrings (p: ''

      [[plugins]]
      id = "${p.id}"
      command = ["mirador-run", "--every", "${toString p.every}", "--title", "${p.title}", "--", "${p.command}"]
    '') panels
    + "# <<< nix\n"
  );
in
{
  home.packages = [
    mirador
    run
  ];

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

  # The plugin declarations are the one part of config.toml nix owns: the marked block at the end is
  # replaced on every switch, everything else (layout, panels on/off) stays mirador's
  home.activation.miradorPlugins = lib.hm.dag.entryAfter [ "miradorConfig" ] ''
    f="$HOME/.config/mirador/config.toml"
    if [ -e "$f" ]; then
      new=$(mktemp "$f.XXXXXX")
      # drop the old block and the blank lines in front of it, then append the current one
      ${pkgs.gawk}/bin/awk '
        /^# >>> nix: external panels/ { skip = 1 }
        !skip { line[++n] = $0 }
        /^# <<< nix/ { skip = 0 }
        END { while (n > 0 && line[n] == "") n--; for (i = 1; i <= n; i++) print line[i] }
      ' "$f" >"$new"
      printf '\n' >>"$new"
      cat ${pluginBlock} >>"$new"
      if ${pkgs.diffutils}/bin/cmp -s "$new" "$f"; then rm -f "$new"; else mv "$new" "$f"; fi
    fi
  '';
}
