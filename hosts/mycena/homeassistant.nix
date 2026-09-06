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

    # Components must be present in the Python environment at build time; HA
    # cannot pull them in at runtime the way a pip-based install would. These
    # are the ones onboarding expects, so the first-run wizard completes.
    extraComponents = [
      "default_config"
      "met" # weather provider onboarding offers
      "radio_browser" # onboarding default
      "esphome"
      "isal" # faster zlib; HA warns without it
    ];

    # Intentionally minimal. Declaring more here makes configuration.yaml a
    # read-only store path, which fights the web UI — and modern HA keeps
    # almost everything in .storage/ anyway. Let onboarding drive.
    config = {
      default_config = { };
    };

    # Serves the UI on :8123 to the LAN, so you can also reach it from amanita
    # or your phone rather than only on the panel itself.
    openFirewall = true;
  };
}
