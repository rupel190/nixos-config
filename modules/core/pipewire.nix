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
    # Rename the GPU's HDMI audio (HDMI 3) so it shows as "Marantz Stereo 70s" in pulsemixer.
    # node.name encodes the HDMI port (extra2 = HDMI 3); changes if you move the cable.
    "51-rename-marantz" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "alsa_output.pci-0000_03_00.1.hdmi-stereo-extra2"; }
          ];
          actions.update-props = {
            "node.description" = "Marantz Stereo 70s";
            "node.nick" = "Marantz Stereo 70s";
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
}
