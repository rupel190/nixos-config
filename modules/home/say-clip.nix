{ pkgs, ... }:
let
  # Kokoro needs misaki for g2p, and misaki's English path needs a spaCy model —
  # spaCy otherwise tries to pip/uv-install it at runtime, which fails on NixOS.
  kokoroPython = pkgs.python3.withPackages (ps: [
    ps.kokoro
    ps.misaki
    ps.spacy-models.en_core_web_sm
  ]);

  kokoro-say = pkgs.writeShellApplication {
    name = "kokoro-say";
    runtimeInputs = [ kokoroPython pkgs.espeak-ng pkgs.procps ];
    text = ''exec ${kokoroPython}/bin/python3 ${./say-clip/kokoro-say.py} "$@"'';
  };

  say-clip = pkgs.writeShellApplication {
    name = "say-clip";
    # Pinning the engines here is the actual fix for the Aug 2026 outage: nixpkgs
    # `piper` (a mouse GUI) shadowed piper-tts on PATH and playback died silently.
    runtimeInputs = [
      kokoro-say
      pkgs.piper-tts
      pkgs.wl-clipboard
      pkgs.sox
      pkgs.pipewire
      pkgs.speechd
      pkgs.python3
      pkgs.gawk
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = builtins.readFile ./say-clip/say-clip.sh;
  };
in
{
  home.packages = [ say-clip kokoro-say ];
}
