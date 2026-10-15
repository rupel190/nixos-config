import { Astal, Gtk } from "ags/gtk4"
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
import {
  MAX_K,
  MIN_K,
  refresh as refreshSunset,
  setColorTemperature,
  temperature,
} from "../service/sunset"
import { wheel } from "./scroll"

// Nerd Font codepoints as escapes rather than literal glyphs, so the source
// stays readable in an editor without the font. Coverage verified in MonaspiceXe
// Nerd Font Mono with `fc-list ":charset=f0379"`.
const ICON_MONITOR = "\u{F0379}" // nf-md-monitor

// One wheel notch, in percent.
const BRIGHTNESS_STEP = 5

// Scroll on the bar button moves the monitor whose percentage the summary is
// showing, so the number under the cursor is the number that changes. No-op
// without the ASUS, for the same reason the summary drops the percentage then.
// setDisplayBrightness already debounces, so a flick collapses to one I²C write.
function adjustGamutBrightness(notches: number) {
  const display = gamut.get()
  if (!display) return
  setDisplayBrightness(display.bus, (brightness.get()[display.bus] ?? 0) + notches * BRIGHTNESS_STEP)
}

// hyprsunset, not DDC: this is a gamma ramp the compositor applies, so it costs
// no I²C and is not per-monitor. It lives here because "how my screens look" is
// one popover, not because it shares a transport with the sliders above.
function TemperatureRow() {
  return (
    <box
      class="row"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={3}
    >
      <box spacing={8}>
        <label class="name" label="All screens" hexpand halign={Gtk.Align.START} />
        <label class="pct" label={createComputed(() => `${temperature() ?? MAX_K}K`)} />
      </box>
      <slider
        hexpand
        min={MIN_K}
        max={MAX_K}
        step={100}
        value={createComputed(() => temperature() ?? MAX_K)}
        $={(self: Astal.Slider) => {
          self.connect("notify::value", () => {
            // Same echo guard as BrightnessRow: a refresh pushes a new value in
            // and fires notify::value exactly as a drag does.
            const next = Math.round(self.value)
            if (next === (temperature.get() ?? MAX_K)) return
            setColorTemperature(next)
          })
        }}
      />
    </box>
  )
}

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
        $={(self: Astal.Slider) => {
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
    <menubutton
      class="Display"
      focusable={false}
      tooltipText="Scroll to dim · click for brightness, gamut and colour temperature"
      $={(self: Gtk.MenuButton) => {
        wheel(self, adjustGamutBrightness)
        // Only the hyprsunset value is re-read on open. Reconciling DDC here too
        // would cost 0.08–0.4s of serialised I²C per monitor on every click,
        // which is exactly why that one is a button instead.
        self.connect("notify::active", () => self.active && refreshSunset())
      }}
    >
      <box spacing={7}>
        <label class="icon" label={ICON_MONITOR} />
        <label class="summary" label={summary} />
      </box>
      <popover>
        <box class="DisplayPopover" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          {/* Hidden rather than dead: without the ASUS there is no bus to write
              0xDC to, and the buttons would silently do nothing. */}
          <box
            orientation={Gtk.Orientation.VERTICAL}
            spacing={8}
            visible={createComputed(() => gamut() !== undefined)}
          >
            <label class="heading" label="Gamut" xalign={0} />
            <GamutToggle />
          </box>

          <label class="heading" label="Brightness" xalign={0} />
          <For each={displays} id={(d: Display) => d.bus}>
            {(d: Display) => <BrightnessRow {...d} />}
          </For>
          <label
            class="empty"
            label="No monitors responding"
            xalign={0}
            visible={createComputed(() => displays().length === 0)}
          />

          {/* Hidden as one block when hyprsunset is not running — a heading over
              nothing reads as a broken control rather than an absent one. */}
          <box
            orientation={Gtk.Orientation.VERTICAL}
            spacing={8}
            visible={createComputed(() => temperature() !== null)}
          >
            <label class="heading" label="Colour temperature" xalign={0} />
            <TemperatureRow />
          </box>

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
