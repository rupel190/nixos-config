{ pkgs, inputs, ... }:
let
  pname = "plasticity";
  version = "26.1.3";

  plasticity-unwrapped = inputs.plasticityAppImage.packages.${pkgs.stdenv.hostPlatform.system}.plasticity;

  # Upstream's AppRun is `exec "$PWD/usr/bin/plasticity"` with no "$@", so the
  # AppImage discards every argument and a file path never reaches Electron.
  # Re-extract with a forwarding AppRun and re-wrap rather than use the input's
  # package. --disable-gpu-shader-disk-cache: ANGLE's program-binary cache goes
  # stale on its own and blanks the viewport (3 incidents, no Mesa change);
  # dropping it measured within noise on startup. Never pass --use-gl=desktop —
  # Chrome 116 rejects it into --use-gl=disabled software rendering.
  appDir = pkgs.appimageTools.extract {
    inherit pname version;
    src = plasticity-unwrapped.src;
    postExtract = ''
      rm -f $out/AppRun
      cat > $out/AppRun <<'EOS'
      #!/bin/sh
      exec "$(dirname "$(readlink -f "$0")")/usr/bin/plasticity" \
        --disable-gpu-shader-disk-cache "$@"
      EOS
      chmod +x $out/AppRun
    '';
  };

  # Our own entry, not upstream's: it uses %U, but Plasticity ignores file://
  # URLs (verified — opens Untitled), so a local path via %f is required.
  desktopItem = pkgs.makeDesktopItem {
    name = "plasticity";
    desktopName = "Plasticity";
    genericName = "3D CAD Modeler";
    comment = "Professional 3D CAD software for artists";
    exec = "plasticity %f";
    icon = "plasticity";
    terminal = false;
    mimeTypes = [
      "application/x-plasticity"
      "model/step"
      "model/stl"
    ];
    categories = [ "Graphics" "3DGraphics" ];
    keywords = [ "CAD" "3D" "Modeling" ];
  };

  # Upstream never installs the icon either: its install step greps a directory
  # absent from the output and swallows the miss with `|| true`.
  plasticity = pkgs.appimageTools.wrapAppImage {
    inherit pname version;
    src = appDir;
    extraInstallCommands = ''
      install -Dm444 -t $out/share/applications ${desktopItem}/share/applications/*
      install -Dm444 ${appDir}/plasticity.png \
        $out/share/icons/hicolor/256x256/apps/plasticity.png
    '';
  };
in
{
  home.packages = [ plasticity ];
}
