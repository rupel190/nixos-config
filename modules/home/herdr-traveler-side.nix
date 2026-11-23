{ pkgs, ... }:

# traveler-side: the traveler layout with its lists rearranged. The spaces run along the top bar
# where the tabs were, and the sidebar holds the tabs on top and the agents below, the active
# ones first. Built from the pinned traveler checkout (same rev as herdr-layouts.nix), so only
# the two new mods, a patched agents mod and a jq rewrite of its layout live here.
let
  src = pkgs.fetchFromGitHub {
    owner = "franky5440-afk";
    repo = "herdr-traveler";
    rev = "a4bb657d5d8533fa9cef0818baa36daee44b7ca1";
    hash = "sha256-Wfk1HJ1h0BeRfml9aLX1nQo3elGOjFbjhB3FBr4jow0=";
  };

  # the shipped tab mod's lib.js, art and window icons come along; only main.js differs
  mod =
    name: js:
    pkgs.runCommand "herdr-${name}" { } ''
      cp -r ${src}/mods/traveler-tabs $out
      chmod -R u+w $out
      cp ${js} $out/main.js
      echo '{ "place": "none", "title": "${name}" }' > $out/mod.json
    '';

  # only about five cards fit, so idle ones sink; within a status the space order stays
  agents = pkgs.runCommand "herdr-traveler-active-agents" { } ''
    cp -r ${src}/mods/traveler-agents $out
    chmod -R u+w $out
    substituteInPlace $out/main.js --replace-fail \
      'const list = agents();' \
      'const rank = (a) => ["blocked", "working", "done"].indexOf(a.status) + 1 || 4;
        const list = [...agents()].sort((x, y) => rank(x) - rank(y));'
  '';

  layout = pkgs.runCommand "traveler-side.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq '
      (.. | objects | select(.id? == "spaces")) |= (.id = "tabs-side" | .content.mod = "traveler-vtabs")
      | (.. | objects | select(.id? == "tabs")) |= (.content.mod = "traveler-spacebar")
      | (.. | objects | select(.id? == "agents")) |= (.content.mod = "traveler-active-agents")
      | del(.cloned_from)
    ' ${src}/layouts/traveler.json > $out
  '';
in
{
  xdg.configFile = {
    "herdr-app/mods/traveler-vtabs".source = mod "traveler-vtabs" ./herdr-traveler-side/vtabs.js;
    "herdr-app/mods/traveler-spacebar".source = mod "traveler-spacebar" ./herdr-traveler-side/spacebar.js;
    "herdr-app/mods/traveler-active-agents".source = agents;
    "herdr-app/layouts/traveler-side.json".source = layout;
  };
}
