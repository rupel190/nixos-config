{ pkgs, ... }:
let
  tera = pkgs.buildGoModule {
    pname = "tera";
    version = "3.11.0";

    src = pkgs.fetchFromGitHub {
      owner = "shinokada";
      repo = "tera";
      rev = "6e6373e640b156b00ae7b64617b11a3a26a7b107";
      hash = "sha256-+PCWgLrQ9uFaFtDOgnsN2klBeG7eVXJ1y/qlb8Gn+vk=";
    };

    vendorHash = "sha256-WugRMPpxj2rQjOrYfpuX58RhMyzLXxHJr8gWgeEJsbU=";

    subPackages = [ "cmd/tera" ];

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postInstall = ''
      wrapProgram $out/bin/tera \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.mpv ]}
    '';

    meta = {
      description = "Keyboard-driven terminal radio player powered by Radio Browser";
      homepage = "https://github.com/shinokada/tera";
      mainProgram = "tera";
    };
  };
in
{
  home.packages = [ tera ];
}
