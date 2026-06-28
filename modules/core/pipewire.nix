{ pkgs, ... }:
{
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # lowLatency.enable = true; # Enable if you need low latency audio
  };

  # WirePlumber device tweaks: match a device by its properties, then override them.
  services.pipewire.wireplumber.extraConfig = {
    # Rename the GPU's HDMI audio (HDMI 3) so it shows as "Marantz" in pulsemixer.
    # node.name encodes the HDMI port (extra2 = HDMI 3); changes if you move the cable.
    "51-rename-marantz" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "alsa_output.pci-0000_03_00.1.hdmi-stereo-extra2"; }
          ];
          actions.update-props = {
            "node.description" = "Marantz";
            "node.nick" = "Marantz";
          };
        }
      ];
    };

    # Hide the ASUS monitor's built-in USB audio card entirely (never used).
    "52-hide-asus-usb-audio" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "device.name" = "alsa_card.usb-Generic_USB_Audio-00"; }
          ];
          actions.update-props = {
            "device.disabled" = true;
          };
        }
      ];
    };
  };

  # Maschine+ monitoring loopback.
  # Capture the Volt 4 rear line inputs 3+4 (RL/RR in the surround-4.0 channel map,
  # where the Maschine's L/R are patched) and play them to the default sink as
  # stereo FL/FR. No playback target.object => it follows whatever sink is default
  # (headset, Marantz, ...). Appears in pulsemixer as "Maschine -> Headset" with its
  # own volume = an independent fader for the Maschine, separate from game audio.
  services.pipewire.extraConfig.pipewire."99-maschine-loopback" = {
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "Maschine -> Headset";
          "capture.props" = {
            "node.name" = "maschine.capture";
            "media.class" = "Stream/Input/Audio";
            "audio.position" = [ "RL" "RR" ]; # Volt inputs 3 + 4
            "target.object" = "alsa_input.usb-Universal_Audio_Volt_4_22312055006964-00.analog-surround-40";
            "stream.dont-remix" = true; # take those exact channels, don't fold
          };
          "playback.props" = {
            "node.name" = "maschine.playback";
            "node.description" = "Maschine -> Headset";
            "media.class" = "Stream/Output/Audio";
            "audio.position" = [ "FL" "FR" ]; # RL->left ear, RR->right ear
          };
        };
      }
    ];
  };
}
