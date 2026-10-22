# Tasshack's Dreame vacuum integration (HACS-only upstream, not in nixpkgs).
# Called through home-assistant.python3Packages.callPackage, the same way
# nixpkgs builds its own custom components, so every dependency below resolves
# against HA's Python and not the system one.
#
# Bump: change version, set hash = lib.fakeHash, rebuild, paste the real one.
# If the build then fails in manifestRequirementsCheck, upstream added a
# requirement to manifest.json; add it to dependencies.
{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  mini-racer,
  numpy,
  paho-mqtt,
  pycryptodome,
  python-miio,
}:

buildHomeAssistantComponent rec {
  owner = "Tasshack";
  domain = "dreame_vacuum";
  version = "2.0.2";

  src = fetchFromGitHub {
    owner = "Tasshack";
    repo = "dreame-vacuum";
    rev = "v${version}";
    hash = "sha256-ZMfmtRNCyTs2F9Yl5rh27AUuCkJokE70VhqbFTAzE/E=";
  };

  dependencies = [
    mini-racer
    numpy
    paho-mqtt
    pycryptodome
    python-miio
  ];

  meta = {
    changelog = "https://github.com/Tasshack/dreame-vacuum/releases/tag/v${version}";
    description = "Home Assistant integration for Dreame robot vacuums";
    homepage = "https://github.com/Tasshack/dreame-vacuum";
    license = lib.licenses.mit;
  };
}
