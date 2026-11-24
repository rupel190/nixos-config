{ config, pkgs, lib, ... }:

# Community layouts for the Herdr desktop app (herdr.dev/gallery), each pinned to a commit
# and linked into ~/.config/herdr-app. Lisa lives in herdr-app.nix.
#
# Reviewed 2026-11-06 per the app's own install notes. Network/exec worth knowing:
#   office-dusty  fetches ipapi.co (your IP -> location) and open-meteo.com for weather
#   lcars         polls 127.0.0.1 (Shepherdr, not installed: silent) and opens URLs with xdg-open
#   rooms         menu items call macOS `open`/`pbcopy`, which do nothing here; also gh/git
#   traveler      runs find/stat/mkdir/open in ~/.config/herdr-app/data/inbox (macOS paths,
#                 patched below), reads job files
#   command-center rewrites its own theme file (kept writable, see the activation below)
# The rest only read git or `hc ls`. A layout's mods start the first time it is shown.

let
  mkLayout =
    {
      name,
      owner,
      repo,
      rev,
      hash,
      sub ? ".",
      layouts,
      mods,
      themes ? [ ],
      rename ? null, # name the repo's `office` goes by here
      patch ? "",
    }:
    let
      pkg =
        pkgs.runCommand "herdr-layout-${name}"
          {
            src = pkgs.fetchFromGitHub { inherit owner repo rev hash; };
          }
          (
            ''
              mkdir -p $out
              cp -r $src/${sub}/layouts $src/${sub}/mods $out/
              ${lib.optionalString (themes != [ ]) "cp -r $src/${sub}/themes $out/"}
              chmod -R u+w $out
            ''
            + lib.optionalString (rename != null) ''
              mv $out/layouts/office.json $out/layouts/${rename}.json
              mv $out/layouts/office.svg $out/layouts/${rename}.svg
              mv $out/mods/office $out/mods/${rename}
              sed -i 's#"mod": "office"#"mod": "${rename}"#; s#layouts/office\.svg#layouts/${rename}.svg#; s#mods/office/#mods/${rename}/#g' \
                $out/layouts/${rename}.json
              { grep -rl 'mods/office/' $out/mods/${rename} || true; } | xargs -r sed -i 's#mods/office/#mods/${rename}/#g'
            ''
            + patch
          );
      link = dir: f: {
        name = "herdr-app/${dir}/${f}";
        value.source = "${pkg}/${dir}/${f}";
      };
    in
    {
      inherit name pkg;
      files = lib.listToAttrs (
        map (link "layouts") layouts ++ map (link "themes") themes ++ map (link "mods") mods
      );
    };

  # detached: a mod's exec waits for the program and fails after 30 s
  inboxOpen = pkgs.writeShellScript "herdr-inbox-open" ''
    ${pkgs.util-linux}/bin/setsid -f ${pkgs.xdg-utils}/bin/xdg-open "$1" </dev/null >/dev/null 2>&1
  '';

  all = [
    # command-center: its theme is written by the mod, so it is copied below, not linked.
    (mkLayout {
      name = "command-center";
      owner = "jhin1m";
      repo = "herdr-command-center";
      rev = "ff9d2add752755ed4a66a7de6377b63f3a2d29bc";
      hash = "sha256-cAc9iOoQ7AV02tw7jQYeWqcEeKDGH6YRzkUEayPRsDw=";
      layouts = [
        "command-center.json"
        "command-center-down.json"
        "command-center-left.json"
        "command-center-side.json"
      ];
      mods = [ "command-center" ];
    })
    (mkLayout {
      name = "arcade";
      owner = "sushmitsarmah";
      repo = "herdr-layouts";
      rev = "5c0136fe4656416448f7813b39b9fd39460e1d6c";
      hash = "sha256-gxGfivNEYhgj2h0BSbj4n+sE3urG/vxY3mDtaw41rGg=";
      sub = "arcade";
      layouts = [ "arcade.json" ];
      mods = [ "arcade" ];
    })
    (mkLayout {
      name = "office";
      owner = "zuccs";
      repo = "herdr-office-layout";
      rev = "773ff6c059f86450027448e22d15ffe5ad9c2ab9";
      hash = "sha256-idheZvqRquh4pY9aRorjl4g6kOMve0YQHYZf3lXcJ0s=";
      sub = "office";
      layouts = [
        "office.json"
        "office.svg"
      ];
      mods = [ "office" ];
    })
    (mkLayout {
      name = "rooms";
      owner = "s3kzk";
      repo = "herdr-rooms";
      rev = "088ba397f8fc70554aee94422e1c5067fc984302";
      hash = "sha256-BDnSg1e1QN+PM1kXk2TpUhFkxAKeNwwldeccB9s05S0=";
      layouts = [ "rooms.json" ];
      mods = [
        "agents-calm"
        "pane-calm"
        "rooms"
        "tabs-graph"
      ];
    })
    (mkLayout {
      name = "orrery";
      owner = "isaacin42";
      repo = "herdr-layouts";
      rev = "73bf616382d6b5c0ae5f73edf3cd122c4f51cda9";
      hash = "sha256-3zitaorrfVNM58Q0PiNtL/Iq7TnygzmAqk7P/4R4t0I=";
      sub = "orrery";
      layouts = [
        "orrery.json"
        "orrery.svg"
      ];
      themes = [ "orrery.json" ];
      mods = [ "orrery" ];
    })
    (mkLayout {
      name = "bloomberg";
      owner = "isaacin42";
      repo = "herdr-layouts";
      rev = "73bf616382d6b5c0ae5f73edf3cd122c4f51cda9";
      hash = "sha256-3zitaorrfVNM58Q0PiNtL/Iq7TnygzmAqk7P/4R4t0I=";
      sub = "bloomberg";
      layouts = [
        "bloomberg.json"
        "bloomberg.svg"
      ];
      themes = [ "bloomberg.json" ];
      mods = [ "bloomberg" ];
    })
    (mkLayout {
      name = "crew-board";
      owner = "vib-z";
      repo = "herdr-layouts";
      rev = "e4619fad4d5dea423fe1ebf2c296de7e6964f52d";
      hash = "sha256-h+8yDju9GbruLpJfmDNqINsuV5rbHUSi8y5jLxvHz3A=";
      sub = "crew-board";
      layouts = [ "crew-board.json" ];
      themes = [ "crew-board.json" ];
      mods = [ "crew-board" ];
    })
    (mkLayout {
      name = "office-dusty";
      owner = "DustyPolk";
      repo = "herdr-office";
      rev = "1a176d580f6dfce386f8379d0bf75b764c31a016";
      hash = "sha256-/MfYy4HwhCZOAouU8DAmbN1DmABWcr74eRNThiBPpp0=";
      rename = "office-dusty";
      layouts = [
        "office-dusty.json"
        "office-dusty.svg"
      ];
      mods = [ "office-dusty" ];
    })
    (mkLayout {
      name = "lcars";
      owner = "jkuepker";
      repo = "herdr-layouts";
      rev = "ea5a9c75e3242928bdc4a2571919a43ec977509b";
      hash = "sha256-RCZrWsnYmWwA/MC2Cp6PyRkpFS8Jzhy36S1P/qyGPa0=";
      sub = "lcars";
      layouts = [ "lcars.json" ];
      mods = [ "lcars" ];
    })
    (mkLayout {
      name = "traveler";
      owner = "franky5440-afk";
      repo = "herdr-traveler";
      rev = "a4bb657d5d8533fa9cef0818baa36daee44b7ca1";
      hash = "sha256-Wfk1HJ1h0BeRfml9aLX1nQo3elGOjFbjhB3FBr4jow0=";
      layouts = [
        "traveler.json"
        "traveler.png"
      ];
      themes = [ "traveler-dusk.json" ];
      mods = [
        "inbox"
        "traveler-agents"
        "traveler-chrome"
        "traveler-spaces"
        "traveler-tabs"
      ];
      # inbox calls /bin/mkdir and BSD stat; %f is the raw mode, 8xxx = regular file
      patch = ''
        substituteInPlace $out/mods/inbox/main.js \
          --replace-fail '"/bin/mkdir"' '"${pkgs.coreutils}/bin/mkdir"'
        substituteInPlace $out/mods/inbox/lib.js \
          --replace-fail '"/usr/bin/find"' '"${pkgs.findutils}/bin/find"' \
          --replace-fail '"/usr/bin/stat", "-f", "%m %z %N"' '"${pkgs.coreutils}/bin/stat", "-c", "%Y %s %n"' \
          --replace-fail '"/usr/bin/stat", args: ["-f", "%HT", path]' '"${pkgs.coreutils}/bin/stat", args: ["-c", "%f", path]' \
          --replace-fail 'String(stdout ?? "").trim() === "Regular File"' '/^8[0-9a-f]{3}$/.test(String(stdout ?? "").trim())' \
          --replace-fail '"/usr/bin/open"' '"${inboxOpen}"'
      '';
    })
  ];

  # office-wall (from ~/Downloads/herdr-office-wall.tar.gz, install.sh reproduced here):
  # a second app home showing only the zuccs office, for a spare monitor, on the same
  # herdr-core. Its sed patch makes a click on a worker focus the agent in the MAIN window
  # (via `herdr-app do agent.focus`, the one program it runs). No network.
  mainHome = "${config.home.homeDirectory}/.config/herdr-app";
  wallHome = ".config/herdr-office-wall";
  wallOffice = pkgs.runCommand "herdr-office-wall-mod" { } ''
    cp -r ${(lib.findFirst (l: l.name == "office") null all).pkg}/mods/office $out
    chmod -R u+w $out
    sed -i \
      -e 's/knownAgents } from "herdr";/knownAgents, exec } from "herdr";/' \
      -e 's/this\.demo = !!p\.demo;/this.demo = !!p.demo; this.mainHome = p.mainHome;/' \
      -e 's/run("agent\.focus", { terminal: a\.address })/focusMain(a.address, this.mainHome)/g' \
      $out/main.js
    cat >> $out/main.js <<'JS'

    // office-wall: focus in the main Herdr window when this copy runs on its own screen.
    function focusMain(terminal, mainHome) {
      if (!mainHome) return run("agent.focus", { terminal });
      exec("env", [`HERDR_APP_HOME=''${mainHome}`, "herdr-app", "do", "agent.focus", "--terminal", terminal])
        .catch(() => run("agent.focus", { terminal }));
    }
    JS
    grep -q 'focusMain(a.address' $out/main.js
  '';
  # The Building (herdr-building/RECIPE.md): the wall's real layout. Office's art.js and font stay
  # as shipped; facts.py reads the core and the transcripts, on a pinned python.
  officeMod = "${(lib.findFirst (l: l.name == "office") null all).pkg}/mods/office";
  building = pkgs.runCommand "herdr-building-mod" { } ''
    mkdir -p $out
    cp -r ${officeMod}/art.js ${officeMod}/fonts $out/
    cp ${./herdr-building/main.js} $out/main.js
    cp ${./herdr-building/people.js} $out/people.js
    cp ${./herdr-building/demo.js} $out/demo.js
    cp ${./herdr-building/facts.py} $out/facts.py
    cp ${./herdr-building/mod.json} $out/mod.json
  '';
  officeWall = pkgs.writeShellScriptBin "office-wall" ''
    # Opens The Building on its own window (second Herdr app home, same herdr-core).
    export HERDR_APP_HOME="''${WALL_HOME:-$HOME/${wallHome}}"
    herdr-app "$@" &
    for _ in $(seq 50); do herdr-app status >/dev/null 2>&1 && break; sleep 0.2; done
    herdr-app do layout.switch --name building >/dev/null
    wait
  '';
in
{
  home.packages = [ officeWall ];

  xdg.configFile = lib.foldl' (acc: l: acc // l.files) { } all // {
    "herdr-office-wall/mods/office".source = wallOffice;
    "herdr-office-wall/mods/building".source = building;
    "herdr-office-wall/layouts/building.json".text = builtins.toJSON {
      id = "building-root-node";
      type = "column";
      titlebar = "none";
      theme = "graphite";
      font_size = 13;
      ui_font = "Geist";
      background = "#1c2028";
      colors = {
        background = "#1e2230";
        accent = "#e2a465";
        border = "#8a5530";
      };
      resizable = false;
      children = [
        {
          id = "building";
          type = "block";
          size.weight = 1;
          content = {
            mod = "building";
            props = {
              inherit mainHome;
              python = "${pkgs.python3}/bin/python3";
            };
          };
        }
      ];
    };
    "herdr-office-wall/layouts/office-wall.json".text = builtins.toJSON {
      id = "office-wall-root";
      type = "column";
      titlebar = "none";
      theme = "graphite";
      font_size = 13;
      ui_font = "Geist";
      background = "#8a5530";
      colors = {
        background = "#1e2230";
        accent = "#e2a465";
        border = "#8a5530";
      };
      resizable = false;
      children = [
        {
          id = "office-floor";
          type = "block";
          size.weight = 1;
          window_drag = true;
          content = {
            mod = "office";
            props.mainHome = mainHome;
          };
        }
      ];
    };
  };

  # The wall's own settings (the app writes zoom here too, so create-if-missing, not a link):
  # no double sounds or toasts, the main window already does those.
  home.activation.herdrOfficeWallSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/${wallHome}/settings.json"
    if [ ! -e "$f" ]; then
      mkdir -p "$(dirname "$f")"
      echo '{ "sounds": { "enabled": false } }' > "$f"
    fi
  '';

  # The command-center mod rewrites its theme to change the accent, so it needs a real file.
  home.activation.herdrCommandCenterTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    t="$HOME/.config/herdr-app/themes/command-center.json"
    if [ ! -e "$t" ]; then
      mkdir -p "$(dirname "$t")"
      install -m644 ${(builtins.head all).pkg.src}/themes/command-center.json "$t"
    fi
  '';
}
