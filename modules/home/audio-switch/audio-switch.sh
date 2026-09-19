# Cycle the default audio sink around a ring declared in default.nix, or jump
# straight to one by label. $DEVICES is that ring, baked in as a store path.
#
# Deliberately a binary rather than logic inside the bar: the Hyprland keybind,
# the bar's speaker icon and a bare shell all reach one implementation, and
# switching keeps working when AGS is down. The bar needs no push — it watches
# each endpoint's `notify::is-default`, which fires for an external wpctl write
# exactly as it does for its own.

usage() {
  echo "usage: audio-switch [LABEL]" >&2
  echo "  no argument   cycle to the next available output in the ring" >&2
  echo "  LABEL         switch to that output (case-insensitive)" >&2
  jq -r '"  ring: " + ([.[].label] | join(" -> "))' "$DEVICES" >&2
}

case "${1-}" in
-h | --help)
  usage
  exit 0
  ;;
esac

# `wpctl inspect` opens with "id 83, type PipeWire:Interface:Node". Empty when
# nothing is default at all (every sink gone), which the jq below treats the same
# as a default sitting outside the ring.
current=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n '1s/^id \([0-9]\+\).*/\1/p')

# One pw-dump, one jq: resolve the ring against what is actually present, then
# pick the target. Ring order is preserved because `$ring[]` drives the outer
# loop — so the cycle follows the order declared in Nix, not PipeWire's
# enumeration order, which shuffles between boots.
target=$(pw-dump | jq -r \
  --argjson ring "$(cat "$DEVICES")" \
  --arg current "${current:-}" \
  --arg want "${1-}" '
  [ .[]
    | select(.type == "PipeWire:Interface:Node")
    | .info.props as $p
    | select($p."media.class" == "Audio/Sink")
    | { id: .id, desc: ($p."node.description" // $p."node.name" // "") }
  ] as $sinks

  # An entry with no sink present drops out entirely, so a powered-off headset is
  # skipped rather than cycled into as a dead default.
  | [ $ring[]
      | . as $r
      | ([ $sinks[] | select(.desc | test($r.match)) ] | first)
      | select(. != null)
      | { id: .id, label: $r.label }
    ] as $present

  | if ($present | length) == 0 then
      "none"
    elif $want != "" then
      ([ $present[] | select(.label | ascii_downcase == ($want | ascii_downcase)) ] | first)
      // "unknown"
    else
      # index() is null when the current default is not in the ring (the Volt,
      # say); starting at 0 then means one press lands back on the ring instead
      # of doing nothing.
      ( ($present | map(.id | tostring) | index($current)) as $i
        | $present[ if $i == null then 0 else (($i + 1) % ($present | length)) end ] )
    end

  | if type == "string" then . else "\(.id)\t\(.label)" end
')

case "$target" in
none)
  echo "audio-switch: no output in the ring is present" >&2
  exit 1
  ;;
unknown)
  echo "audio-switch: no available output labelled '${1-}'" >&2
  usage
  exit 1
  ;;
esac

IFS=$'\t' read -r id label <<<"$target"

# This moves streams that are already playing, not only new ones — WirePlumber
# re-links every stream that has no pinned target.object. So this one call is the
# whole switch; nothing has to chase the individual streams.
wpctl set-default "$id"
echo "$label"

# A toast as well as the bar, because the bar is a layer surface that a
# fullscreen game covers — which is exactly when the keybind gets used. hyprctl
# rather than notify-send: Hyprland draws this itself, so it survives swaync's
# do-not-disturb (same reasoning as the idle-inhibit bind in keybinds.nix).
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE-}" ]; then
  hyprctl notify -1 1500 "rgb(8bd5ca)" "Audio: $label" >/dev/null
fi
