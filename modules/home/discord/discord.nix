{ ... }:
{
  # Vesktop: Discord web + Vencord, own config dir. Settings deliberately left mutable —
  # declaring them writes /nix/store symlinks and the in-app toggles stop saving.
  # Replaces the official client entirely: its native voice engine hands PipeWire one
  # pre-mixed stream, while Vesktop's Chromium audio path allows per-element setSinkId.
  programs.vesktop.enable = true;
}
