{ pkgs, inputs, ... }:
let
  pname = "plasticity";
  version = "26.1.3";

  plasticity-unwrapped = inputs.plasticityAppImage.packages.${pkgs.stdenv.hostPlatform.system}.plasticity;

  # Upstream's AppRun is `exec "$PWD/usr/bin/plasticity"` with no "$@", so the
  # AppImage discards every argument — a file path from yazi or xdg-open never
  # reaches Electron and Plasticity opens an empty session. Re-extract with a
  # forwarding AppRun and re-wrap ourselves rather than use the input's package.
  # Note this makes CLI flags live again: do NOT add --use-gl=desktop, which
  # Chrome 116 (Electron 26) rejects into --use-gl=disabled software rendering.
  appDir = pkgs.appimageTools.extract {
    inherit pname version;
    src = plasticity-unwrapped.src;
    postExtract = ''
      rm -f $out/AppRun
      cat > $out/AppRun <<'EOS'
      #!/bin/sh
      exec "$(dirname "$(readlink -f "$0")")/usr/bin/plasticity" "$@"
      EOS
      chmod +x $out/AppRun
    '';
  };

  # Upstream also never installs the icon: its install step greps a directory
  # that doesn't exist in the output and swallows the miss with `|| true`, so
  # Icon=plasticity resolves to nothing and every launcher shows a blank tile.
  plasticity = pkgs.appimageTools.wrapAppImage {
    inherit pname version;
    src = appDir;
    extraInstallCommands = ''
      install -Dm444 -t $out/share/applications \
        ${plasticity-unwrapped}/share/applications/plasticity.desktop
      install -Dm444 ${appDir}/plasticity.png \
        $out/share/icons/hicolor/256x256/apps/plasticity.png
    '';
  };
in
{
  home.packages = [ plasticity ];
}
