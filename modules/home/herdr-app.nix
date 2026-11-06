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
      install -Dm755 herdr-app $out/libexec/herdr-app/herdr-app
      install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
      install -Dm644 LICENSE $out/share/licenses/herdr-app/LICENSE
      # The app starts herdr-core from PATH.
      makeWrapper $out/libexec/herdr-app/herdr-app $out/bin/herdr-app \
        --prefix PATH : ${lib.makeBinPath [ herdr-core ]}
    '';

    meta.mainProgram = "herdr-app";
  };
in
{
  home.packages = [
    herdr-app
    herdr-core
  ];
}
