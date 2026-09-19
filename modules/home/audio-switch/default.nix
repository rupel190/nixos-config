{ config, pkgs, ... }:
let
  # The output ring — what CTRL+SUPER+ALT+A and the bar's speaker icon cycle
  # through, in this order. Nix owns this LIST; `audio-switch` does the
  # switching and modules/home/ags/widget/Audio.tsx does the drawing, both from
  # this one declaration.
  #
  # `match` is a regex against a sink's node.description — the name wpctl and
  # pulsemixer print. Description rather than node.name on purpose: the Marantz
  # arrives as `alsa_output.pci-….hdmi-stereo-extra2`, where `extra2` encodes
  # which HDMI port the cable is in, so moving the cable renames the node. The
  # description is stable because modules/core/pipewire.nix assigns it, which
  # keeps a cable move a one-line fix in that one file.
  #
  # ⚠️ The BlackShark enumerates as TWO cards — the 2.4GHz dongle (USB
  # 1532:0577, "BlackShark V3 Pro Analog Stereo") and the USB-C cable
  # (1532:0576, "BlackShark V3 Pro USB Analog Stereo"). The `Analog` anchor
  # picks the dongle and excludes the wired card, which would otherwise join the
  # ring uninvited whenever the headset is on charge.
  #
  # `icon` is a vocabulary, not a glyph: the bar maps it to a Nerd Font
  # codepoint. Known values are "speaker" and "headset"; anything else draws the
  # speaker.
  outputs = [
    {
      match = "^Marantz";
      label = "Marantz";
      icon = "speaker";
    }
    {
      match = "^BlackShark V3 Pro Analog";
      label = "BlackShark";
      icon = "headset";
    }
  ];

  devices = pkgs.writeText "audio-devices.json" (builtins.toJSON outputs);
in
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "audio-switch";
      runtimeInputs = [
        pkgs.wireplumber # wpctl
        pkgs.pipewire # pw-dump
        pkgs.jq
        pkgs.coreutils
        # Only used for the toast, but taken from the config rather than PATH so
        # this is the same hyprctl as the running compositor.
        config.wayland.windowManager.hyprland.package
      ];
      bashOptions = [
        "nounset"
        "pipefail"
      ];
      text = ''
        DEVICES=${devices}
        ${builtins.readFile ./audio-switch.sh}
      '';
    })
  ];

  # The same table the bar reads, for its label and icon. It cannot be handed a
  # store path the way the script is — ~/.config/ags is an out-of-store symlink
  # into the working tree — so it arrives at a fixed config path instead. See
  # readRing() in modules/home/ags/service/audio.ts.
  xdg.configFile."audio-switch/devices.json".source = devices;
}
