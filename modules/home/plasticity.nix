{ pkgs, inputs, ... }:
{
  home.packages = [ inputs.plasticityAppImage.packages.${pkgs.system}.plasticity ];
}
