{ pkgs, inputs, ... }:
let
  plasticity-unwrapped = inputs.plasticityAppImage.packages.${pkgs.system}.plasticity;

  # gfx1201 (RX 9070 XT) workaround: Chromium's default ANGLE path mistypes WebGL
  # vertex attributes on this GPU's non-conformant RADV Vulkan, so every draw is
  # rejected and the viewport renders nothing ("won't load projects"). Forcing
  # native desktop GL (radeonsi 4.6, which is conformant) bypasses ANGLE and
  # restores GPU-accelerated rendering. Both the launcher (.desktop Exec=plasticity)
  # and the yazi opener call `plasticity` from PATH, so wrapping the binary covers
  # every launch path. Drop once Mesa fixes RADV/ANGLE on gfx1201.
  plasticity = pkgs.symlinkJoin {
    name = "plasticity-gldesktop";
    paths = [ plasticity-unwrapped ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/plasticity --add-flags "--use-gl=desktop"
    '';
  };
in
{
  home.packages = [ plasticity ];
}
