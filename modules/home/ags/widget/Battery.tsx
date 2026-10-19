import { createComputed } from "ags"
import { type Battery as State, battery } from "../service/battery"

// nf-md-battery-10 … battery-90 are consecutive codepoints, then battery (full)
// sits one below them. Coverage verified in MonaspiceXe Nerd Font Mono with
// `fc-list ":charset=f007a"`.
const ICON_FULL = "\u{F0079}" // nf-md-battery
const ICON_EMPTY = "\u{F008E}" // nf-md-battery-outline
const ICON_CHARGING = "\u{F0241}" // nf-md-flash
const ICON_PLUG = "\u{F06A5}" // nf-md-power-plug

// Same threshold as the peripherals: below it the number is worth a glance.
const LOW = 20

function levelIcon(capacity: number): string {
  if (capacity >= 95) return ICON_FULL
  if (capacity < 5) return ICON_EMPTY
  // 5–14 → battery-10, … 85–94 → battery-90.
  return String.fromCodePoint(0xf007a + Math.min(8, Math.round(capacity / 10) - 1))
}

function duration(hours: number): string {
  const m = Math.round(hours * 60)
  return `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, "0")}m`
}

function tooltip(b: State): string {
  const parts = [`Battery ${b.capacity}% — ${b.status.toLowerCase()}`]
  if (b.hours !== null) parts.push(`${duration(b.hours)} ${b.status === "Charging" ? "to full" : "left"}`)
  if (b.watts !== null) parts.push(`${b.watts.toFixed(1)} W`)
  return parts.join("  ·  ")
}

export default function Battery() {
  // Hidden on hosts without one (amanita), and if the battery is ever pulled.
  const visible = createComputed(() => battery() !== null)
  const b = () => battery() ?? { capacity: 0, status: "", ac: false, hours: null, watts: null }

  return (
    <box
      class={createComputed(() => (b().capacity <= LOW && !b().ac ? "Battery stat low" : "Battery stat"))}
      spacing={6}
      visible={visible}
      tooltipText={createComputed(() => tooltip(b()))}
    >
      <label class="icon" label={createComputed(() => levelIcon(b().capacity))} />
      <label class="value" label={createComputed(() => `${b().capacity}%`)} xalign={0} />
      {/* Flash while charging; a plug when the charger is in but not charging
          (full, or held below 100 by a charge threshold). */}
      <label
        class="charging"
        label={createComputed(() => (b().status === "Charging" ? ICON_CHARGING : ICON_PLUG))}
        visible={createComputed(() => b().ac)}
      />
    </box>
  )
}
