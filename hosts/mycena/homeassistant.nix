# Home Assistant server, running on mycena itself for now.
#
# Kept in its own file deliberately: if this graduates to a Raspberry Pi later,
# the move is (1) import this file from the Pi's host instead, and (2) copy
# /var/lib/hass across. Nothing else here depends on it.
#
# NOTE this makes mycena STATEFUL. Everything you configure through the HA web
# UI — devices, dashboards, users, automations, history — lands in
# /var/lib/hass (mostly .storage/), NOT in this repo. A reinstall via
# nixos-anywhere reproduces the service but not its contents, so that directory
# is the thing worth backing up.
{ ... }:
{
  services.home-assistant = {
    enable = true;

    # HA's python env is immutable here, so it cannot pip-install an
    # integration at runtime. "No module named X" + UnknownHandler in the log
    # is a TODO list: name the component here and rebuild.
    extraComponents = [
      "default_config"
      "met" # weather provider onboarding offers
      "radio_browser" # onboarding default
      "esphome"
      "isal" # faster zlib; HA warns without it

      # Found by discovery on this LAN, 2026-09-06:
      "hue" # Philips Hue bridge      (needed aiohue)
      "samsungtv" # Samsung TV               (needed getmac)
      "heos" # Denon/Marantz HEOS       (needed pyheos)
      # "hue_ble"   # only for driving Hue bulbs over Bluetooth directly,
      #             # rather than through the bridge above

      # Talks to the local Piper TTS server configured below. Deliberately not
      # "gtts": that one is Google's cloud service and ships every phrase you
      # speak to them. Piper runs the model on this machine instead.
      "wyoming"
    ];

    # Kept minimal on purpose. Declaring more here makes configuration.yaml a
    # read-only store path, which fights the web UI — and modern HA keeps
    # almost everything in .storage/ anyway. Let the UI drive.
    # Auth is deliberately left at HA's default (password only). A
    # trusted_networks provider scoped to loopback would let the panel log
    # itself in, but a one-time login on the panel achieves the same thing
    # without any auth exemption: HA keeps a long-lived refresh token in the
    # browser, so it effectively never asks again.
    config = {
      default_config = { };
    };

  };

  # Local text-to-speech, as an alternative to the "gtts" component HA keeps
  # offering. gtts is Google Translate's TTS: every phrase HA speaks would be
  # sent to Google. Piper runs a small neural voice model on this machine, so
  # nothing leaves the LAN and it works with the internet down.
  #
  # Bound to loopback only — HA is the sole client and it runs on this host, so
  # there is no reason to expose the port. Voice samples to pick from:
  # https://rhasspy.github.io/piper-samples/  (de_DE-thorsten-medium for German)
  #
  # Wire it up afterwards in HA: Settings > Devices > Add Integration >
  # Wyoming Protocol, host 127.0.0.1, port 10200.
  services.wyoming.piper.servers.main = {
    enable = true;
    voice = "en-us-ryan-medium";
    uri = "tcp://127.0.0.1:10200";
  };

  # services.home-assistant.openFirewall is gone — it now fails an assertion,
  # because HA no longer takes its frontend port from configuration.yaml, so
  # the module cannot know the port at evaluation time. Open it by hand.
  # 8123 is HA's default and is only changeable from inside the web UI; if you
  # ever change it there, change it here too.
  networking.firewall.allowedTCPPorts = [ 8123 ];
}
