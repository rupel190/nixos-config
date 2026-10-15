import { Gtk } from "ags/gtk4"
import { createComputed } from "ags"
import { adjustVolume, cycle, output } from "../service/audio"
import { wheel } from "./scroll"

// Nerd Font codepoints as escapes rather than literal glyphs, so the source
// stays readable in an editor without the font. Names confirmed against the
// MonaspiceXe cmap, not guessed from a cheat sheet.
const ICON_MUTED = "\u{F0581}" // nf-md-volume_off

// The `icon` vocabulary of the ring in modules/home/audio-switch/default.nix.
// Adding a key here is what lets a new entry there draw as something other than
// a speaker.
const ICON: Record<string, string> = {
  speaker: "\u{F04C3}", // nf-md-speaker
  headset: "\u{F02CB}", // nf-md-headphones
}

export default function AudioIndicator() {
  const icon = createComputed(() => {
    const o = output()
    if (!o) return ICON.speaker
    if (o.mute) return ICON_MUTED
    return ICON[o.icon] ?? ICON.speaker
  })

  // An em dash rather than hiding the widget: no default sink at all is an
  // anomaly worth seeing, and the button still works — clicking it puts the
  // machine back on the first output in the ring that answers.
  const name = createComputed(() => output()?.label ?? "—")
  const pct = createComputed(() => {
    const o = output()
    return o ? `${o.volume}%` : ""
  })

  return (
    <button
      class={createComputed(() => (output()?.mute ? "Audio muted" : "Audio"))}
      focusable={false}
      tooltipText="Click to switch output · scroll to set volume"
      onClicked={() => cycle()}
      $={(self: Gtk.Button) => wheel(self, adjustVolume)}
    >
      <box spacing={7}>
        <label class="icon" label={icon} />
        <label class="name" label={name} />
        <label class="pct" label={pct} xalign={0} />
      </box>
    </button>
  )
}
