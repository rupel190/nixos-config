import { readFile } from "ags/file"
import { createState } from "ags"
import { interval } from "ags/time"

// CPU + memory, moved off the WezTerm tabline — see the note above `tabline_z`
// in modules/home/wezterm.nix. The two numbers cost ~23 columns of a 124-column
// tab bar there, which is space the tab titles wanted.

export type Ram = {
  usedGiB: number
  totalGiB: number
  pct: number
}

// Read straight out of procfs with Gio rather than shelling out to free/awk the
// way the tabline components did (four forks a second, per window). /proc files
// report st_size 0, but g_file_load_contents reads to EOF into a growing buffer,
// so this works and costs no process — the same trade Clock.tsx makes vs `date`.
const STAT = "/proc/stat"
const MEMINFO = "/proc/meminfo"

// The CPU figure is a mean over the sample window: shorter is noisier without
// being more informative, longer swallows brief spikes entirely.
const POLL_MS = 2000

// null until the first real reading — the em dash convention service/ddc.ts
// already uses. CPU especially cannot produce a value from a single sample.
const [cpu, setCpu] = createState<number | null>(null)
const [ram, setRam] = createState<Ram | null>(null)
export { cpu, ram }

// /proc/stat's counters are cumulative jiffies since boot, so a percentage means
// something only as a delta between two samples. Worth stating outright, because
// the tabline component this replaces divided the totals instead —
// (user+system)/(user+system+idle) — which is the since-boot *average*: a number
// that reads plausibly and then never moves. Measured 3.67% twice, 4s apart.
let prev: { busy: number; total: number } | null = null

function sampleCpu() {
  const line = readFile(STAT).split("\n", 1)[0]
  // user nice system idle iowait irq softirq steal. guest and guest_nice follow
  // but are already counted inside user and nice, so summing all ten would
  // double-count virtualised time.
  const v = line.split(/\s+/).slice(1, 9).map(Number)
  const total = v.reduce((a, b) => a + b, 0)
  const busy = total - v[3] - v[4] // minus idle and iowait

  const last = prev
  prev = { busy, total }
  if (!last) return

  const elapsed = total - last.total
  if (elapsed <= 0) return
  setCpu(Math.round(((busy - last.busy) / elapsed) * 100))
}

function sampleRam() {
  const info = readFile(MEMINFO)
  const kB = (key: string) => Number(info.match(new RegExp(`^${key}:\\s+(\\d+)`, "m"))?.[1])
  const total = kB("MemTotal")
  const available = kB("MemAvailable")
  if (!total || !available) return

  // MemTotal - MemAvailable, not the older total-free-buffers-cached: available
  // is the kernel's own estimate of what a fresh allocation could claim, so
  // reclaimable page cache stops counting as used.
  const used = total - available
  setRam({
    usedGiB: used / 1048576,
    totalGiB: total / 1048576,
    pct: Math.round((used / total) * 100),
  })
}

let timer: ReturnType<typeof interval> | null = null

export function init() {
  // Guarded rather than trusting the single call in app.ts: the CPU delta is
  // module-level state, and two interleaved samplers would each see a fraction
  // of the elapsed jiffies and both report nonsense.
  if (timer) return
  // interval() fires once immediately, so the priming sample that CPU needs is
  // taken at startup rather than costing an extra POLL_MS before the first value.
  timer = interval(POLL_MS, () => {
    sampleCpu()
    sampleRam()
  })
}
