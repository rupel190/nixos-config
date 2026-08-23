{ pkgs, inputs, ... }:
let
  plasticity-unwrapped = inputs.plasticityAppImage.packages.${pkgs.stdenv.hostPlatform.system}.plasticity;

  # Upstream's AppRun is `exec "$PWD/usr/bin/plasticity"` with no "$@", so the
  # AppImage silently discards every argument — flags never reach Electron, and
  # neither does a file path from yazi or xdg-open. A `--use-gl=desktop` wrapper
  # lived here as the gfx1201 blank-viewport fix; it was inert for that reason,
  # and Chrome 116 (Electron 26) rejects the value anyway, so actually delivering
  # it would drop us to software rendering. Blank viewport = stale ANGLE program
  # binaries: clear ~/.config/Plasticity/{GPUCache,DawnCache}.
  # The upstream AppImage package ships plasticity.desktop (Icon=plasticity) but
  # never installs the icon: its install step does
  #   find $out/share/plasticity -name plasticity.png | xargs install ...
  # and that directory doesn't exist in the output, so the match is empty and the
  # trailing `|| true` swallows the miss → Icon=plasticity resolves to nothing and
  # every launcher (vicinae, the "Open With" chooser) shows a blank tile. Recover
  # the real 256x256 icon by re-extracting the AppImage (exposed as `.src`) and
  # dropping it onto the hicolor theme path ourselves.
  appDir = pkgs.appimageTools.extract {
    pname = "plasticity";
    version = "26.1.3";
    src = plasticity-unwrapped.src;
  };

  plasticity = pkgs.symlinkJoin {
    name = "plasticity-with-icon";
    paths = [ plasticity-unwrapped ];
    postBuild = ''
      install -Dm444 ${appDir}/plasticity.png \
        $out/share/icons/hicolor/256x256/apps/plasticity.png
    '';
  };
in
{
  home.packages = [ plasticity ];
}
