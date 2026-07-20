{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  visualizer = {
    src = pkgs.fetchFromGitHub {
      owner = "Konsl";
      repo = "spicetify-visualizer";
      rev = "dist";
      hash = "sha256-lEXu3IySLoqy1W3UXhCh3Ho9rwpFHGYgJDnSyVYaoe0=";
    };
    name = "index.js";
  };
  # singify — UltraStar karaoke overlay. Built from source by the singify flake
  # input (no copied-in binary). To ship new changes: push to the singify repo,
  # then `nix flake update singify` here and rebuild.
  singify = {
    src = inputs.singify.packages.${pkgs.stdenv.hostPlatform.system}.default;
    name = "karaoke.js";
  };
in
{
  # Note: Spotify unfree package is allowed via system-wide nixpkgs.config.allowUnfree in modules/core/system.nix

  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;

    # RDNA 4 rendering fix:
    # - Native Wayland mode (NIXOS_OZONE_WL=1 default) hits a CEF/Chromium 143 assertion
    #   in wp_color_manager_v1 handling on Hyprland 0.54 (SIGTRAP crash).
    # - X11 + ANGLE-over-Vulkan SIGABRTs outright since the 2026-06 Mesa bump: the
    #   ANGLE→RADV path on GFX1201 aborts the GPU process and wedges the whole session
    #   (confirmed via coredump 2026-07-01, "froze when switching to Spotify").
    # - `--use-gl=desktop` (the prior fix) went stale when Spotify moved to Chrome 146:
    #   that value was removed from Chromium ~M112, so GL init failed and the GPU process
    #   fell back to `--use-gl=disabled` (software compositing, sluggish). 2026-07-20.
    # Fix: force X11 (wayland=false overrides NIXOS_OZONE_WL) + ANGLE-over-native-GL
    # (`--use-angle=gl` → radeonsi), which keeps hardware accel while still bypassing the
    # ANGLE→Vulkan/RADV path that crashes. Verified: gpu-process runs use-gl=angle.
    wayland = false;
    spotifyPackage = pkgs.spotify.overrideAttrs (old: {
      preFixup = (old.preFixup or "") + ''
        gappsWrapperArgs+=(--add-flags "--use-gl=angle")
        gappsWrapperArgs+=(--add-flags "--use-angle=gl")
        gappsWrapperArgs+=(--add-flags "--enable-gpu-rasterization")
        gappsWrapperArgs+=(--add-flags "--ignore-gpu-blocklist")
      '';
    });

    enabledExtensions = with spicePkgs.extensions; [
      visualizer
      singify
      adblock
      hidePodcasts
      shuffle # shuffle+ True shuffle using the Fisher-Yates algorithm (zero bias).
      keyboardShortcut # vim-like keybinds
      bookmark # Save and quickly access pages, tracks, or specific timestamps.
      trashbin # Skip songs or artists automatically. They’ll never play again.
      loopyLoop # Loop a specific portion of a track.
      phraseToPlaylist # Given a phrase, this extension will make a playlist containing a series of songs which make up that phrase.
      lastfm # Integration with last.fm. Login to show your listening stats for a song, and get its last.fm link.
      # genre # Display the genre of an artist or song while playing.
      hidePodcasts # hidePodcasts
      playNext # Add track to the top of the queue.
    ];
    enabledCustomApps = with spicePkgs.apps; [
      # lyrics-plus # Advanced lyrics display with multiple providers (Musixmatch, Netease, LRCLIB).
      # new-releases # Aggregates new releases from artists and podcasts you follow
      marketplace # (Browsing only!) Add a page where you can browse extensions, themes, apps, and snippets. Using the marketplace does not work with this flake, however it is still here in order to allow for browsing.
    ];

    theme = spicePkgs.themes.catppuccin;
    colorScheme = "macchiato";
  };
}
