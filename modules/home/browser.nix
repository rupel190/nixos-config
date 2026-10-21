{
  inputs,
  pkgs,
  ...
}:
let
  zenPkgs = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system};
  # upstream re-uploaded the 1.23.3b tarball after the flake pinned its hash; self-expires on the next version
  zen =
    if zenPkgs.zen-browser-unwrapped.version == "1.23.3b" then
      zenPkgs.zen-browser.override {
        zen-browser-unwrapped = zenPkgs.zen-browser-unwrapped.override {
          hash = "sha256-uyBF0+IWVNQP6EElAJLurf0sH8gx7vtQkiJ3PIvcoUk=";
        };
      }
    else
      zenPkgs.default;
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
