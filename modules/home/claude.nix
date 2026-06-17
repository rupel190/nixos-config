{ pkgs, inputs, ... }:
let
  # Build claude-desktop locally so we can override nodePackages.asar → pkgs.asar
  # (nodePackages was removed from nixpkgs; upstream flake hasn't been updated yet)
  patchy-cnb = pkgs.callPackage "${inputs.claude-desktop}/pkgs/patchy-cnb.nix" {};
  claude-desktop = pkgs.callPackage "${inputs.claude-desktop}/pkgs/claude-desktop.nix" {
    inherit patchy-cnb;
    nodePackages = { asar = pkgs.asar; };
  };
  claude-desktop-with-fhs = pkgs.buildFHSEnv {
    name = "claude-desktop";
    targetPkgs = pkgs: with pkgs; [ docker glibc openssl nodejs uv ];
    runScript = "${claude-desktop}/bin/claude-desktop";
    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cp ${claude-desktop}/share/applications/claude.desktop $out/share/applications/
      mkdir -p $out/share/icons
      cp -r ${claude-desktop}/share/icons/* $out/share/icons/
    '';
  };
in
{
  home.packages = [
    inputs.claude-code.packages.${pkgs.system}.default
    pkgs.claude-monitor
    claude-desktop-with-fhs
  ];
}
