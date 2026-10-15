{
  inputs,
  pkgs,
  ...
}:
let
  zen = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages = [
    # the flake's wrapper never puts ffmpeg on the dlopen path: no H264 software decode and no AAC at all
    (pkgs.symlinkJoin {
      name = "zen-browser-ffmpeg";
      paths = [ zen ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/zen --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.ffmpeg.lib ]}
      '';
    })
  ];
}
