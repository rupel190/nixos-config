{ pkgs, lib, ... }:

# Herdr desktop app (herdr.dev, github.com/herdrdev/herdr-app) and its separate
# runtime, herdr-core. Not the terminal UI in herdr.nix, and not in nixpkgs, so both
# are the upstream release binaries from releases.herdr.dev.
#
# The app's own updater and the first-run core download write to ~/.local and cannot
# touch the store: bump the versions and hashes below instead (releases.herdr.dev/
# {app,core}/latest.json). Layouts and mods live in ~/.config/herdr-app, not here.

let
  herdr-core = pkgs.stdenv.mkDerivation rec {
    pname = "herdr-core";
    version = "0.1.18";

    src = pkgs.fetchurl {
      url = "https://releases.herdr.dev/core/${version}/herdr-core-linux-x86_64.tar.gz";
      hash = "sha256-Wy+Xy0sqnXprLMWUJiggPtn7t8wMK0sJrYpvVkjiRrc=";
    };

    # Statically linked, so it only needs unpacking.
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      install -Dm755 herdr-core $out/bin/herdr-core
      ln -s herdr-core $out/bin/hc
    '';

    meta.mainProgram = "herdr-core";
  };

  herdr-app = pkgs.stdenv.mkDerivation rec {
    pname = "herdr-app";
    version = "0.1.13";

    src = pkgs.fetchurl {
      url = "https://releases.herdr.dev/app/${version}/herdr-app-linux-x86_64.tar.gz";
      hash = "sha256-d7C+cqRsoUuzZzZaBBZGQfkUs6aXErrDkdOcVqlZvvQ=";
    };

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.makeWrapper
      pkgs.copyDesktopItems
    ];

    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.libxcb
      pkgs.libxkbcommon
    ];

    # dlopen()ed at runtime (wgpu/winit), so autoPatchelf cannot see them.
    runtimeDependencies = [
      pkgs.vulkan-loader
      pkgs.libGL
      pkgs.wayland
      pkgs.libxkbcommon
      pkgs.libxcb
    ];

    sourceRoot = "herdr-app";
    dontConfigure = true;
    dontBuild = true;

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "herdr-app";
        desktopName = "Herdr";
        comment = "Terminals and coding agents that keep running";
        exec = "herdr-app";
        icon = "herdr-app";
        categories = [ "Development" ];
        startupWMClass = "herdr-app";
      })
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 herdr-app $out/libexec/herdr-app/herdr-app
      install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
      install -Dm644 LICENSE $out/share/licenses/herdr-app/LICENSE
      # The app starts herdr-core from PATH, and a core it starts hands the app's environment
      # to every terminal it opens, apart from TERM, COLORTERM and TERM_PROGRAM; a core that
      # already runs keeps the environment it started with. So:
      # - herdr-app#533: graphics reply arrives after DA1; drop once fixed. Without it Claude
      #   Code decides there is no Kitty graphics and the image mod (claude.nix) draws alt text.
      # - kitty's variables go, for an app started from a kitty shell: the claude hooks would
      #   paint that kitty tab, and TERMINFO names kitty's terminfo.
      makeWrapper $out/libexec/herdr-app/herdr-app $out/bin/herdr-app \
        --prefix PATH : ${lib.makeBinPath [ herdr-core ]} \
        --set CLAUDE_CODE_FORCE_TERMINAL_IMAGES 1 \
        --unset KITTY_WINDOW_ID \
        --unset KITTY_LISTEN_ON \
        --unset KITTY_PID \
        --unset KITTY_PUBLIC_KEY \
        --unset KITTY_INSTALLATION_DIR \
        --unset TERMINFO
      runHook postInstall # copyDesktopItems hangs off this hook
    '';

    meta.mainProgram = "herdr-app";
  };
  # Lisa layout (github.com/billyhunt/herdr-lisa): neon school-supplies look, built for
  # herdr 0.1.11. Reviewed: its mods only run git and `hc machine ls` and use localStorage,
  # no network. install.sh's copy steps, with the shared lisa.js placed in each mod.
  lisa = pkgs.runCommand "herdr-lisa" {
    src = pkgs.fetchFromGitHub {
      owner = "billyhunt";
      repo = "herdr-lisa";
      rev = "0ab7e71d3730bdb403bce7f6d28f43cecbbaa22f";
      hash = "sha256-Sq0B6kXoqNLk/gAsLB7JMeeBBpEMgrgoK6BoCyuUaxQ=";
    };
  } ''
    mkdir -p $out/mods
    cp -r $src/lisa/{layouts,themes,fonts,backgrounds} $out/
    for m in $src/lisa/mods/*; do
      cp -r $m $out/mods/
      chmod -R u+w $out/mods/$(basename $m)
      cp $src/lisa/lisa-kit/lisa.js $out/mods/$(basename $m)/lisa.js
    done
  '';
  # One directory link per mod; mods/ itself stays the app's.
  lisaMods = lib.genAttrs (map (m: "herdr-app/mods/${m}") [
    "lisa-agents"
    "lisa-pane"
    "lisa-spaces"
    "lisa-tabs"
    "lisa-workspace-chrome"
    "lisa-workspace-status"
  ]) (n: { source = "${lisa}/mods/${baseNameOf n}"; });

  # The app writes settings.json itself (zoom from the zoom keys, the Settings screen),
  # so only the keys below are merged in and the rest of the file is left alone.
  settings = {
    theme = "catppuccin-macchiato";
    colors = {
      accent = "#8bd5ca"; # teal, as in herdr.nix
      chrome = "#1e2030"; # mantle
      selected = "#363a4f"; # surface0
    };
    telemetry = false; # herdr.nix likewise never calls herdr.dev
  };
in
{
  home.packages = [
    herdr-app
    herdr-core
  ];

  # Same keys as herdr.nix where the app has an equivalent: alt+hjkl moves tabs and
  # spaces, so pane focus is ctrl+shift+hjkl (its layout.switch and picker moved to ctrl+alt+l/k). force: the app creates these files
  # on first start.
  xdg.configFile = lisaMods // {
    "herdr-app/keys.json" = {
      source = ./dotfiles/herdr-app/keys.json;
      force = true;
    };
    "herdr-app/mods/tab-left".source = ./dotfiles/herdr-app/mods/tab-left;
    "herdr-app/mods/tab-right".source = ./dotfiles/herdr-app/mods/tab-right;
    "herdr-app/themes/catppuccin-macchiato.json".source = ./dotfiles/herdr-app/catppuccin-macchiato.json;
    "herdr-app/layouts/lisa.json".source = "${lisa}/layouts/lisa.json";
    "herdr-app/layouts/lisa.png".source = "${lisa}/layouts/lisa.png";
    "herdr-app/layouts/lisa-airbrush.json".source = "${lisa}/layouts/lisa-airbrush.json";
    "herdr-app/layouts/lisa-airbrush.png".source = "${lisa}/layouts/lisa-airbrush.png";
    "herdr-app/themes/lisa-day.json".source = "${lisa}/themes/lisa-day.json";
    "herdr-app/themes/lisa-dusk.json".source = "${lisa}/themes/lisa-dusk.json";
    "herdr-app/fonts".source = "${lisa}/fonts";
    "herdr-app/backgrounds".source = "${lisa}/backgrounds";
    "herdr-core/config.toml".text = ''
      shell = ["fish"]
    '';
  };

  home.activation.herdrAppSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.config/herdr-app/settings.json"
    if [ -f "$f" ]; then
      ${pkgs.jq}/bin/jq --argjson s '${builtins.toJSON settings}' '. * $s' "$f" > "$f.new" && mv "$f.new" "$f"
    fi
  '';
}
