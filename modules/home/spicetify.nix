{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in
{
  # Note: Spotify unfree package is allowed via system-wide nixpkgs.config.allowUnfree in modules/core/system.nix

  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;

    enabledExtensions = with spicePkgs.extensions; [
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
