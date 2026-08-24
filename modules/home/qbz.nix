{ pkgs, lib, ... }:
let
  version = "2.0.2";

  src = pkgs.fetchurl {
    url = "https://github.com/vicrodh/qbz/releases/download/v${version}/QBZ_${version}_amd64.AppImage";
    hash = "sha256-Kz3EEbP2tCm4oRXvMYUlnUQn6hjZRG2mQvQzQDhXj9U=";
  };

  # AppImage rather than pkgs.qbz (stuck on 1.2.15, the pre-2.0 Tauri build) or
  # upstream's flake (source build, ~30 GB rustc peak per its own comment).
  # Same args wrapType2 extracts with internally, so this shares that derivation.
  appDir = pkgs.appimageTools.extract {
    pname = "qbz";
    inherit version src;
  };

  qbz = pkgs.appimageTools.wrapType2 {
    pname = "qbz";
    inherit version src;

    # No extraPkgs: the default FHS set already carries every runtime lib QBZ
    # dlopens (wayland, libxkbcommon, vulkan-loader, libGL, alsa-lib, libjack2).

    # wrapAppImage installs only $out/bin/qbz, so the AppImage's own entry and
    # icon would never reach a launcher (Exec=qbz resolves from PATH).
    extraInstallCommands = ''
      install -Dm444 ${appDir}/qbz.desktop $out/share/applications/qbz.desktop
      install -Dm444 ${appDir}/qbz.png $out/share/icons/hicolor/256x256/apps/qbz.png
    '';

    meta = {
      description = "Native hi-fi Qobuz desktop player with bit-perfect playback";
      homepage = "https://qbz.lol";
      license = lib.licenses.mit;
      mainProgram = "qbz";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  home.packages = [ qbz ];
}
