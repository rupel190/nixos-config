# Home Assistant server, running on mycena itself for now.
#
# Kept in its own file deliberately: if this graduates to a Raspberry Pi later,
# the move is (1) import this file from the Pi's host instead, taking
# ./ha-components/ along with it, and (2) copy /var/lib/hass across. Nothing
# else here depends on it.
#
# NOTE this makes mycena STATEFUL. Everything you configure through the HA web
# UI — devices, dashboards, users, automations, history — lands in
# /var/lib/hass (mostly .storage/), NOT in this repo. A reinstall via
# nixos-anywhere reproduces the service but not its contents, so that directory
# is the thing worth backing up.
{ pkgs, ... }:
let
  # HA's own Python set, which is what nixpkgs builds custom components against.
  haPython = pkgs.home-assistant.python3Packages;
  mini-racer = haPython.callPackage ./ha-components/mini-racer.nix { };
  dreame-vacuum = haPython.callPackage ./ha-components/dreame-vacuum.nix { inherit mini-racer; };
in
{
  services.home-assistant = {
    enable = true;

    # Integrations nixpkgs does not ship, which HACS would normally install.
    # HACS can drop the code in, but for the same reason as extraComponents
    # below it cannot pip-install requirements, so anything with dependencies
    # gets packaged in ./ha-components/ instead.
    #
    # dreame_vacuum, for the Dreame L40 Ultra (serial R2492): Settings > Devices
    # > Add Integration > Dreame Vacuum, then the Dreamehome account and region
    # the robot is paired in. CLOUD-ONLY for this robot: "Local Connection"
    # needs a Xiaomi Home device and a token pulled from Xiaomi's cloud, and the
    # L40 family is not a Xiaomi Home device. Its frontend.py (obfuscated)
    # phones api.tasshack.com only once a paid card licence key is entered;
    # without one it makes no call there.
    #
    # INTERIM. The L40 Ultra is on Valetudo's supported list (fastboot root,
    # Dreame Breakout PCB recommended, warranty seals stay intact), which takes
    # it off Dreame's cloud entirely. Once rooted, replace this with nixpkgs'
    # home-assistant-custom-components.valetudo + the "mqtt" component, a
    # services.mosquitto broker, and the valetudo-map-card lovelace module,
    # then delete ./ha-components/. None of that needs custom packaging.
    customComponents = [ dreame-vacuum ];

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
      # The Marantz announces itself twice. denonavr is receiver control
      # (power/volume/inputs) over SSDP; heos is Denon's multiroom streaming
      # platform. Different feature sets, so both.
      "denonavr"
      "heos"
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

  # Local TTS instead of the "gtts" component onboarding defaults to, which
  # ships every spoken phrase to Google. Costs a 2.8 GiB closure (it pulls the
  # pytorch training stack, not just onnx inference) -- viable only because the
  # bluetooth coexistence fix below took wifi from 28 KB/s to 4 MB/s.
  #
  # Wire it up in HA: Settings > Devices > Add Integration > Wyoming Protocol,
  # host 127.0.0.1, port 10200.
  services.wyoming.piper.servers.main = {
    enable = true;
    voice = "en-us-ryan-medium";
    uri = "tcp://127.0.0.1:10200";
  };

  # piper-tts pulls pyopenjtalk-plus, whose test suite fails on nixpkgs 02c087f
  # (py3.14 reworded a TypeError the test regex-matches) and Hydra has no cached
  # build. Same version-guarded fix as modules/core/system.nix, repeated here
  # because this host does not import modules/core. Self-expires on the next
  # pyopenjtalk-plus release.
  nixpkgs.overlays = [
    (_final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_pyfinal: pyprev: {
          pyopenjtalk-plus =
            if pyprev.pyopenjtalk-plus.version == "0.4.1-post9" then
              pyprev.pyopenjtalk-plus.overridePythonAttrs (old: {
                disabledTests = (old.disabledTests or [ ]) ++ [
                  "test_run_njd_from_mecab_invalid_input_should_not_break_next_call"
                ];
              })
            else
              pyprev.pyopenjtalk-plus;
        })
      ];
    })
  ];

  # services.home-assistant.openFirewall is gone — it now fails an assertion,
  # because HA no longer takes its frontend port from configuration.yaml, so
  # the module cannot know the port at evaluation time. Open it by hand.
  # 8123 is HA's default and is only changeable from inside the web UI; if you
  # ever change it there, change it here too.
  networking.firewall.allowedTCPPorts = [ 8123 ];
}
