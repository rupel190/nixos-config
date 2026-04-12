{ pkgs, lib, ... }:
{
  programs = {
    steam = {
      enable = true;

      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      localNetworkGameTransfers.openFirewall = true;

      # gamescopeSession.enable = true;

      # TODO: Explicit definition required?
      extraCompatPackages = [ pkgs.proton-ge-bin ];

      package = pkgs.steam.override {
        # ! Disable AVX-512 CPU instructions to avoid Steam SIGILL issues
        extraProfile = ''
          export GLIBC_TUNABLES=glibc.cpu.hwcaps=-AVX512F
        '';
        extraPkgs =
          pkgs: with pkgs; [
            libxcursor
            libxi
            libxinerama
            libxscrnsaver
            libpng
            libpulseaudio
            libvorbis
            stdenv.cc.cc.lib
            libkrb5
            keyutils
            freetype
            fontconfig
          ];
      };
    };

    # Gamescope: Gaming compositor/microcompositor - DISABLED
    # Use with: gamescope [options] -- %command% in Steam launch options
    # Or: gamescope -W 2560 -H 1440 -r 240 -- game-binary
    # gamescope = {
    #   enable = true;
    #   capSysNice = true; # Allow real-time scheduling for better performance
    #   args = [
    #     "--rt" # Enable real-time scheduling
    #     "--expose-wayland" # Expose Wayland socket to games
    #   ];
    # };

    # Enable gamemode for automatic CPU governor switching
    # gamemode = {
    #   enable = true;
    #   settings = {
    #     general = {
    #       renice = 10;
    #     };
    #     custom = {
    #       start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
    #       end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
    #     };
    #   };
    # };
  };
}
