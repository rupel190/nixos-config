import { Gtk } from "ags/gtk4"
import { For, createComputed } from "ags"
import {
  type Display,
  PROFILE_LABEL,
  Profile,
  brightness,
  displays,
  gamut,
  profile,
  refresh,
  setDisplayBrightness,
  setDisplayProfile,
} from "../service/ddc"

// Nerd Font codepoints as escapes rather than literal glyphs, so the source
// stays readable in an editor without the font. Coverage verified in GeistMono
// Nerd Font Mono with `fc-list ":charset=f0379"`.
const ICON_MONITOR = "\u{F0379}" // nf-md-monitor

function BrightnessRow(display: Display) {
  const value = createComputed(() => brightness()[display.bus] ?? 0)

  return (
    <box class="row" orientation={Gtk.Orientation.VERTICAL} spacing={3}>
      <box spacing={8}>
        <label class="name" label={display.model} hexpand halign={Gtk.Align.START} />
        <label class="pct" label={createComputed(() => `${value()}%`)} />
      </box>
      <slider
        hexpand
        min={0}
        max={100}
        step={5}
        value={value}
        $={(self) => {
          self.connect("notify::value", () => {
            const next = Math.round(self.value)
            // `value` is bound into the widget, so a DDC read pushes a new value
            // and fires notify::value exactly as a user drag does. If the widget
            // already agrees with state this was that echo, and writing it back
            // would cost the monitor an NVRAM cycle for nothing.
            if (next === Math.round(value.get())) return
            setDisplayBrightness(display.bus, next)
          })
        }}
      />
    </box>
  )
}

// 0xDC is GameVisual and only the ASUS implements it, so this whole control
// hides when that monitor is absent rather than failing at write time.
function GamutToggle() {
  const segClass = (p: number) =>
    createComputed(() => (profile() === p ? "seg active" : "seg"))

  return (
    <box class="segmented">
      <button class={segClass(Profile.SRGB)} onClicked={() => setDisplayProfile(Profile.SRGB)}>
        <label label="sRGB" />
      </button>
      <button class={segClass(Profile.USER)} onClicked={() => setDisplayProfile(Profile.USER)}>
        <label label="DCI-P3" />
      </button>
    </box>
  )
}

export default function DisplayIndicator() {
  const summary = createComputed(() => {
    const p = profile()
    // Deliberately not ddcutil's labels for 0xDC — it prints the MCCS standard
    // meanings, which are wrong on this panel.
    const mode = p === null ? "—" : (PROFILE_LABEL[p] ?? `0x${p.toString(16)}`)
    const g = gamut()
    const pct = g ? brightness()[g.bus] : undefined
    return pct === undefined ? mode : `${mode} · ${pct}%`
  })

  return (
    <menubutton class="Display" focusable={false} tooltipText="Monitor brightness and gamut">
      <box spacing={7}>
        <label class="icon" label={ICON_MONITOR} />
        <label class="summary" label={summary} />
      </box>
      <popover>
        <box class="DisplayPopover" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          <label class="heading" label="Gamut" xalign={0} />
          <GamutToggle />

          <label class="heading" label="Brightness" xalign={0} />
          <For each={displays} id={(d: Display) => d.bus}>
            {(d: Display) => <BrightnessRow {...d} />}
          </For>

          {/* DDC/CI has no change notification, so a change made at the monitor's
              own OSD is invisible until something asks. Polling for it would cost
              0.08–0.4s of serialised I²C per monitor per tick, so it is a button. */}
          <button class="refresh" onClicked={() => refresh()}>
            <label label="Re-read from monitors" />
          </button>
        </box>
      </popover>
    </menubutton>
  )
}
