{ pkgs, lib, host, ... }:
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

      # TEMP (2026-07-02): reverted from pkgs.millennium-steam to vanilla pkgs.steam.
      # Steam auto-updated its client (buildid 1782866176 / Chrome 126) and Millennium
      # 3.3.0-beta.7's cef_browser_host_create_browser hook deadlocks the new webhelper
      # → UI hangs at 100% CPU on every launch. No injection = no hook = no hang.
      # Restore `pkgs.millennium-steam.override` once a Millennium build supports this
      # Steam client (the flake.lock already stages a newer rev to try first).
      package = pkgs.steam.override {
        # ! Disable AVX-512 CPU instructions to avoid Steam SIGILL issues
        extraProfile = ''
          export GLIBC_TUNABLES=glibc.cpu.hwcaps=-AVX512F
        ''
        # cordyceps (laptop) only: Hyprland's xwayland { force_zero_scaling = true }
        # reports scale 1 to XWayland, so Steam's client UI renders tiny on the
        # HiDPI eDP-1 panel. Scale the desktop UI back up. Tune to taste (1.5/2).
        + lib.optionalString (host == "cordyceps") ''
          export STEAM_FORCE_DESKTOPUI_SCALING=1.5
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
