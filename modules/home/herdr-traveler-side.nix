{ pkgs, ... }:

# traveler-side: the traveler layout with its lists rearranged. The spaces run along the top bar
# where the tabs were, and the sidebar holds the tabs on top and the agents below, the active
# ones first; the Changes panel is gitview (herdr-gitview.nix). Built from the pinned traveler
# checkout (same rev as herdr-layouts.nix), so only the two new mods, a patched agents mod and a
# jq rewrite of its layout live here.
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

  # the shipped cards (as cards.js, so agents.js can extend them) with other bars: HP is the prompt
  # cache's warmth, gone 58 min after the last reply (measured: still cached at 57.7, cold at 59),
  # MP the context left; both come from claude-statusline.py
  agents = pkgs.runCommand "herdr-traveler-active-agents" { } ''
    cp -r ${src}/mods/traveler-agents $out
    chmod -R u+w $out
    mv $out/main.js $out/cards.js
    cp ${./herdr-traveler-side/agents.js} $out/main.js
    substituteInPlace $out/cards.js \
      --replace-fail \
      'const hp = gauge(cache ? cache.hp : null, cache ? cache.updatedAt : null, now);' \
      'const hp = gauge(cache?.hp, cache?.updatedAt);
        if (hp.pct !== null) hp.text = hp.pct > 0 ? `''${Math.ceil(hp.pct * 0.58)}m` : "cold";' \
      --replace-fail \
      'const sp = gauge(cache ? cache.sp : null, cache ? cache.updatedAt : null, now);' \
      'const mp = gauge(cache?.mp, cache?.updatedAt);' \
      --replace-fail 'bar("SP", sp,' 'bar("MP", mp,'
    substituteInPlace $out/lib.js \
      --replace-fail \
      'hp: pct(data.contextRemainingPct),' \
      'repliedAt: data.repliedAt,
        hp: pct(data.repliedAt && Math.max(0, Math.min(100, Math.round(100 - (Date.now() / 1000 - data.repliedAt) / 34.8)))),' \
      --replace-fail 'sp: pct(data.fiveHourRemainingPct),' 'mp: pct(data.contextRemainingPct),'
  '';

  layout = pkgs.runCommand "traveler-side.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq '
      (.. | objects | select(.id? == "spaces")) |= (.id = "tabs-side" | .content.mod = "traveler-vtabs")
      | (.. | objects | select(.id? == "tabs")) |= (.content.mod = "traveler-spacebar")
      | (.. | objects | select(.id? == "agents")) |= (.content.mod = "traveler-active-agents")
      | (.. | objects | select(.id? == "changes")) |= (.content.mod = "gitview")
      | del(.. | objects | select(.id? == "inbox"))
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
