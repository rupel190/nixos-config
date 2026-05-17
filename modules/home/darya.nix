{ pkgs, ... }:
let
  darya = pkgs.rustPlatform.buildRustPackage {
    pname = "darya";
    version = "0.1.5";
    src = pkgs.fetchFromGitHub {
      owner = "mrkatebzadeh";
      repo = "darya";
      rev = "v0.1.5";
      hash = "sha256-EN1yJeiDbIt0TXMI2pRFkygwtfAFNC0BsR/jtq6OoYI=";
    };
    cargoHash = "sha256-uSG19x268zsp+KuP+ry7NjodVyIUUaQ7XjLwGpoBHQ0=";
  };
in
{
  home.packages = [ darya ];
}
