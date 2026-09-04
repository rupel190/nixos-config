import { For, createComputed } from "ags"
import { type Peripheral, peripherals } from "../service/peripherals"

// Nerd Font codepoints as escapes rather than literal glyphs, so the source
// stays readable in an editor without the font. Coverage verified in MonaspiceXe
// Nerd Font Mono with `fc-list ":charset=f037d"`.
const ICON_MOUSE = "\u{F037D}" // nf-md-mouse
const ICON_BATTERY = "\u{F0079}" // nf-md-battery
const ICON_CHARGING = "\u{F0241}" // nf-md-flash

// Below this a wireless peripheral is worth interrupting for; above it the
// number is just trivia and should stay as quiet as the rest of the bar.
const LOW = 20

function Entry(p: Peripheral) {
  return (
    <box
      class={p.capacity <= LOW && !p.charging ? "stat low" : "stat"}
      spacing={6}
      tooltipText={`${p.model} — ${p.capacity}%${p.charging ? ", charging" : ""}`}
    >
      <label class="icon" label={p.isMouse ? ICON_MOUSE : ICON_BATTERY} />
      <label class="value" label={`${p.capacity}%`} xalign={0} />
      <label class="charging" label={ICON_CHARGING} visible={p.charging} />
    </box>
  )
}

export default function Peripherals() {
  // Hidden rather than empty: with nothing paired this would otherwise leave a
  // gap in the end cluster, and it self-heals when the mouse comes back.
  return (
    <box
      class="Peripherals"
      spacing={12}
      visible={createComputed(() => peripherals().length > 0)}
    >
      <For each={peripherals} id={(p: Peripheral) => p.id}>
        {(p: Peripheral) => <Entry {...p} />}
      </For>
    </box>
  )
}
