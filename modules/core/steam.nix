{ pkgs, lib, ... }:
{
  programs = {
    steam = {
      enable = false;

      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      localNetworkGameTransfers.openFirewall = true;

      gamescopeSession.enable = true;

      # TODO: Explicit definition required?
      extraCompatPackages = [ pkgs.proton-ge-bin ];

      package = pkgs.steam.override {
        # ! Disable AVX-512 CPU instructions to avoid Steam SIGILL issues
        extraProfile = ''
          export GLIBC_TUNABLES=glibc.cpu.hwcaps=-AVX512F
        '';
        extraPkgs =
          pkgs: with pkgs; [
            xorg.libXcursor
            xorg.libXi
            xorg.libXinerama
            xorg.libXScrnSaver
            libpng
            libpulseaudio
            libvorbis
            stdenv.cc.cc.lib
            libkrb5
            keyutils
          ];
      };
    };

    # TOOD: What the options do?
    gamescope = {
      enable = true;
      capSysNice = true;
      args = [
        "--rt"
        "--expose-wayland"
      ];
    };
  };
}
