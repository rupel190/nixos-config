import { execAsync } from "ags/process"
import { createState } from "ags"
import { timeout } from "ags/time"

// hyprsunset's colour temperature, over its IPC socket via `hyprctl hyprsunset`.
// The daemon is a user unit declared in modules/home/hyprland/hyprsunset.nix.

// hyprsunset clamps nothing — it accepts 20000 as readily as 2000 and simply
// renders the screen blue — so the usable range is this widget's to enforce.
export const MIN_K = 2000
export const MAX_K = 6500 // sRGB's D65 white point: the neutral end, not a filter

// Values are snapped to this, which keeps the slider's echo guard comparing
// equal numbers and the readout free of 4523K.
const STEP_K = 100

// Far cheaper than a DDC write — a unix socket round trip, ~10ms, no NVRAM —
// but a drag still emits one per frame and each one repaints the gamma ramp on
// every output, so a drag is collapsed into a single write.
const WRITE_DEBOUNCE_MS = 80

// null means there is no daemon to talk to, which hides the control rather than
// offering one that cannot work.
const [temperature, setTemperatureState] = createState<number | null>(null)
export { temperature }

const snap = (k: number) =>
  Math.max(MIN_K, Math.min(MAX_K, Math.round(k / STEP_K) * STEP_K))

export async function refresh() {
  try {
    const out = await execAsync(["hyprctl", "hyprsunset", "temperature"])
    const kelvin = parseInt(out.trim(), 10)
    setTemperatureState(Number.isFinite(kelvin) ? kelvin : null)
  } catch {
    // `hyprctl hyprsunset` exits 3 with "Couldn't connect to ….hyprsunset.sock"
    // when the daemon is down. Not worth logging: it is the expected state on a
    // host where the unit has not started yet.
    setTemperatureState(null)
  }
}

let pending: { cancel(): void } | null = null

export function setColorTemperature(kelvin: number) {
  const next = snap(kelvin)
  // Optimistic, as in ddc.ts: the slider tracks the pointer rather than waiting
  // on the round trip the debounce is about to delay anyway.
  setTemperatureState(next)

  pending?.cancel()
  pending = timeout(WRITE_DEBOUNCE_MS, () => {
    pending = null
    execAsync(["hyprctl", "hyprsunset", "temperature", String(next)]).catch((e) =>
      console.error("sunset: temperature write failed —", e),
    )
  })
}

export function init() {
  // Nothing pushes this value, so it is read once here and again whenever the
  // popover opens — see the menubutton setup in widget/Display.tsx.
  refresh()
}
