{ pkgs, inputs, ... }:
let
  plasticity-unwrapped = inputs.plasticityAppImage.packages.${pkgs.stdenv.hostPlatform.system}.plasticity;

  # gfx1201 (RX 9070 XT) workaround: Chromium's default ANGLE path mistypes WebGL
  # vertex attributes on this GPU's non-conformant RADV Vulkan, so every draw is
  # rejected and the viewport renders nothing ("won't load projects"). Forcing
  # native desktop GL (radeonsi 4.6, which is conformant) bypasses ANGLE and
  # restores GPU-accelerated rendering. Both the launcher (.desktop Exec=plasticity)
  # and the yazi opener call `plasticity` from PATH, so wrapping the binary covers
  # every launch path. Drop once Mesa fixes RADV/ANGLE on gfx1201.
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
    name = "plasticity-gldesktop";
    paths = [ plasticity-unwrapped ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/plasticity --add-flags "--use-gl=desktop"
      install -Dm444 ${appDir}/plasticity.png \
        $out/share/icons/hicolor/256x256/apps/plasticity.png
    '';
  };
in
{
  home.packages = [ plasticity ];
}
