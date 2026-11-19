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

// A drag is throttled, not debounced: the screen should follow the slider in
// steps rather than hold still until the pointer pauses. Each write is a colour
// matrix commit on every output, which stalls Hyprland ~40ms on amdgpu even
// with render.ctm_animation off (measured: p95 23ms at 200ms spacing, 41ms at
// 100ms, 56ms at 50ms, and mostly blocked at 33ms). 10 steps a second is the
// fastest that still leaves most of each gap free; 150ms looked too steppy.
const WRITE_INTERVAL_MS = 100

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
    // What the daemon holds now, so write() never skips a value because some
    // other caller changed the temperature since the bar last wrote it.
    written = Number.isFinite(kelvin) ? kelvin : null
  } catch {
    // `hyprctl hyprsunset` exits 3 with "Couldn't connect to ….hyprsunset.sock"
    // when the daemon is down. Not worth logging: it is the expected state on a
    // host where the unit has not started yet.
    setTemperatureState(null)
  }
}

// Writes run one after another, so the final value of a drag always lands last
// even if an earlier hyprctl is slow to return.
let chain: Promise<unknown> = Promise.resolve()
let written: number | null = null
let waiting: number | null = null
let cooldown: { cancel(): void } | null = null

function write(kelvin: number) {
  if (kelvin === written) return
  written = kelvin
  chain = chain
    .then(() => execAsync(["hyprctl", "hyprsunset", "temperature", String(kelvin)]))
    .catch((e) => console.error("sunset: temperature write failed —", e))
}

// Leading edge writes at once; during the cooldown only the newest value is
// kept, and it goes out when the cooldown ends, which also covers the release.
function flush() {
  cooldown = null
  if (waiting === null) return
  const kelvin = waiting
  waiting = null
  write(kelvin)
  cooldown = timeout(WRITE_INTERVAL_MS, flush)
}

export function setColorTemperature(kelvin: number) {
  const next = snap(kelvin)
  // Optimistic, as in ddc.ts: the slider and readout track the pointer at full
  // rate; only the screen steps at the throttled one.
  setTemperatureState(next)

  waiting = next
  if (!cooldown) flush()
}

export function init() {
  // Nothing pushes this value, so it is read once here and again whenever the
  // popover opens — see the menubutton setup in widget/Display.tsx.
  refresh()
}
