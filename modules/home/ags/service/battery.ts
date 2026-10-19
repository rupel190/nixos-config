import { createState } from "ags"
import { interval } from "ags/time"
import { POWER_SUPPLY, attr, listDir } from "./sysfs"

// The machine's own battery — cordyceps today. Read from sysfs like
// service/peripherals.ts rather than through AstalBattery, because that needs
// upowerd and no host here runs it. ACPI batteries carry no `scope` attribute
// (or scope System); scope Device is a peripheral and is left to that service.

export type Battery = {
  capacity: number
  // Charging, Discharging, Full, or "Not charging" — the last is what a charge
  // threshold reports while the charger is in but holding the cell below 100.
  status: string
  ac: boolean
  // Hours to empty while discharging, to full while charging; null when the
  // firmware gives no rate (it reads 0 for a few seconds after a plug change).
  hours: number | null
  watts: number | null
}

// Short enough that plugging in shows within a glance, still only a handful of
// small file reads per tick.
const POLL_MS = 10_000

const [battery, setBattery] = createState<Battery | null>(null)
export { battery }

// Firmware reports either charge (µAh, µA) or energy (µWh, µW); both pairs give
// the same hours, and only one set exists per battery.
function num(base: string, ...names: string[]): number | null {
  for (const n of names) {
    const raw = attr(`${base}/${n}`)
    if (raw !== null && raw !== "" && Number.isFinite(Number(raw))) return Number(raw)
  }
  return null
}

let last = ""

function sample() {
  let ac = false
  let now = 0
  let full = 0
  let rate = 0
  let watts = 0
  const caps: number[] = []
  const statuses: string[] = []

  for (const id of listDir(POWER_SUPPLY)) {
    const base = `${POWER_SUPPLY}/${id}`
    const type = attr(`${base}/type`)
    if (type === "Mains" && attr(`${base}/online`) === "1") ac = true
    if (type !== "Battery" || attr(`${base}/scope`) === "Device") continue
    if (attr(`${base}/present`) === "0") continue

    const capacity = num(base, "capacity")
    if (capacity === null) continue
    caps.push(capacity)
    statuses.push(attr(`${base}/status`) ?? "Unknown")

    now += num(base, "charge_now", "energy_now") ?? 0
    full += num(base, "charge_full", "energy_full") ?? 0
    const r = Math.abs(num(base, "current_now", "power_now") ?? 0)
    rate += r
    const power = num(base, "power_now")
    const volts = num(base, "voltage_now")
    watts += power !== null ? power / 1e6 : volts !== null ? (r * volts) / 1e12 : 0
  }

  let next: Battery | null = null
  if (caps.length > 0) {
    // Several cells (some ThinkPads) combine by charge, not by averaging the
    // percentages; the mean is only the fallback when charge is not reported.
    const capacity =
      full > 0 ? Math.round((now / full) * 100) : Math.round(caps.reduce((a, b) => a + b) / caps.length)
    const status = statuses.includes("Charging")
      ? "Charging"
      : statuses.includes("Discharging")
        ? "Discharging"
        : statuses[0]

    let hours: number | null = null
    if (rate > 0 && status === "Discharging") hours = now / rate
    if (rate > 0 && status === "Charging" && full > now) hours = (full - now) / rate

    next = { capacity, status, ac, hours, watts: watts > 0 ? watts : null }
  }

  const key = JSON.stringify(next)
  if (key === last) return
  last = key
  setBattery(next)
}

let timer: ReturnType<typeof interval> | null = null

export function init() {
  if (timer) return
  timer = interval(POLL_MS, sample)
}
