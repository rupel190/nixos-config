import { execAsync } from "ags/process"
import { createComputed, createState } from "ags"
import { timeout } from "ags/time"

// DDC/CI monitor control. There is no Astal library for this, so everything goes
// through the `ddcutil` binary (declared in modules/home/packages.nix; the i2c
// group membership and hardware.i2c.enable that make it work without sudo are in
// modules/core/{user,hardware}.nix).

// ── VCP codes ────────────────────────────────────────────────────────────────

const BRIGHTNESS = "0x10"
const GAMEVISUAL = "0xDC"

// GameVisual values as they behave on the PG27AQDM. ddcutil prints the MCCS
// *standard* meanings for 0xDC — it calls 0x03 "Movie" — and those are wrong on
// this panel, where 0x03 is sRGB Mode. Never surface ddcutil's own labels.
export const Profile = {
  SRGB: 0x03, // clamped sRGB gamut — colour-accurate work
  USER: 0x04, // native gamut, i.e. DCI-P3 on this WOLED panel
  RACING: 0x05,
} as const

export const PROFILE_LABEL: Record<number, string> = {
  [Profile.SRGB]: "sRGB",
  [Profile.USER]: "P3",
  [Profile.RACING]: "Racing",
}

// Monitors persist brightness to NVRAM on *every* DDC write, and the I²C bus is
// slow and serialised. A slider dragged without debouncing issues hundreds of
// writes — the one scenario where NVRAM wear is a genuine concern rather than a
// theoretical one. This collapses a whole drag into a single write.
const WRITE_DEBOUNCE_MS = 200

export type Display = {
  bus: number
  connector: string
  model: string
}

// ── State ────────────────────────────────────────────────────────────────────
// DDC/CI has no change notification and reads cost 0.08s (ASUS) to 0.4s (Dell)
// of serialised I²C, so polling is off the table. The bar keeps an authoritative
// cache instead: it is the source of truth for anything it set, and reconciles
// with the hardware only on demand. OSD-side changes are therefore invisible
// until refresh() is called.

const [displays, setDisplays] = createState<Display[]>([])
const [brightness, setBrightness] = createState<Record<number, number>>({})
const [profile, setProfile] = createState<number | null>(null)
const [ready, setReady] = createState(false)

// The gamut control is ASUS-specific — 0xDC is GameVisual and the Dell does not
// implement it — so everything profile-related is scoped to this one display.
const gamut = createComputed(() => displays().find((d) => d.model.includes("PG27AQDM")))

export { brightness, displays, gamut, profile, ready }

// ── Serialisation ────────────────────────────────────────────────────────────

// Only one process may talk to an I²C bus at a time; concurrent ddcutil calls
// degrade into DDC retries and hard errors. Every invocation is threaded through
// this chain so they run strictly one after another, whoever asked.
let queue: Promise<unknown> = Promise.resolve()

function serial<T>(fn: () => Promise<T>): Promise<T> {
  const run = queue.then(fn, fn)
  // The chain itself must never stay in a rejected state, or a single failed
  // read would reject every call queued behind it.
  queue = run.then(
    () => {},
    () => {},
  )
  return run
}

function ddc(bus: number, ...args: string[]): Promise<string> {
  return serial(() => execAsync(["ddcutil", "--bus", String(bus), ...args]))
}

// ── Parsing ──────────────────────────────────────────────────────────────────

// `--terse` continuous reply: "VCP 10 C 80 100" — current, then max.
function parseContinuous(out: string): number | null {
  const m = out.match(/VCP\s+\S+\s+C\s+(\d+)\s+(\d+)/)
  return m ? Number(m[1]) : null
}

// `--terse` simple-non-continuous reply: "VCP DC SNC x04".
function parseSimple(out: string): number | null {
  const m = out.match(/VCP\s+\S+\s+SNC\s+x([0-9a-fA-F]+)/)
  return m ? parseInt(m[1], 16) : null
}

// `detect --brief` emits blank-line-separated blocks, headed either "Display N"
// or "Invalid display". This drops the obviously-invalid ones, but that header
// is NOT a capability check — see probeBrightness below.
function parseDetect(out: string): Display[] {
  return out
    .split(/\n\s*\n/)
    .filter((block) => /^Display\s+\d+/m.test(block))
    .map((block) => {
      const bus = block.match(/\/dev\/i2c-(\d+)/)
      if (!bus) return null
      return {
        bus: Number(bus[1]),
        connector: block.match(/DRM connector:\s+card\d+-(\S+)/)?.[1] ?? "?",
        model: block.match(/Monitor:\s+[^:]+:([^:]*):/)?.[1]?.trim() ?? "unknown",
      }
    })
    .filter((d): d is Display => d !== null)
}

// ── Reads ────────────────────────────────────────────────────────────────────

// `ddcutil detect` cannot be trusted to say which monitors actually speak DDC.
// The Samsung C24F390 was observed enumerating as "Invalid display" on one run
// and "Display 1" on the very next, while failing every real DDC exchange in
// both cases. The only reliable test is to ask it for something.
//
// A monitor that does not answer costs ~2.1s to fail (against ~0.09s for one
// that does), so this runs exactly once at startup — and it doubles as the
// initial brightness read, which makes the verification free for the ones that
// do work.
async function probeBrightness(bus: number): Promise<boolean> {
  try {
    const value = parseContinuous(await ddc(bus, "--terse", "getvcp", BRIGHTNESS))
    if (value === null) return false
    setBrightness((prev) => ({ ...prev, [bus]: value }))
    return true
  } catch {
    return false
  }
}

// Returns whether the read landed, so refresh() can tell a stale display list
// apart from a monitor that merely changed at its OSD.
async function readBrightness(bus: number): Promise<boolean> {
  try {
    const value = parseContinuous(await ddc(bus, "--terse", "getvcp", BRIGHTNESS))
    if (value === null) return false
    setBrightness((prev) => ({ ...prev, [bus]: value }))
    return true
  } catch (e) {
    console.error(`ddc: brightness read failed on bus ${bus} —`, e)
    return false
  }
}

async function readProfile() {
  const display = gamut.get()
  if (!display) return
  try {
    setProfile(parseSimple(await ddc(display.bus, "--terse", "getvcp", GAMEVISUAL)))
  } catch (e) {
    console.error("ddc: profile read failed —", e)
  }
}

// ── Public API ───────────────────────────────────────────────────────────────

// `ddcutil detect` costs ~3.4s, so it runs exactly once, at startup. Bus numbers
// were stable across a reboot on this machine but are not guaranteed to be,
// which is why they are resolved at runtime instead of hardcoded.
//
// Do NOT try to derive the bus from /sys/class/drm/card1-DP-*/ddc — that symlink
// points at the legacy DDC-pin bus, which carries EDID only. DisplayPort tunnels
// I²C over the AUX channel, a separate adapter on amdgpu.
export async function init() {
  try {
    const candidates = parseDetect(
      await serial(() => execAsync(["ddcutil", "detect", "--brief"])),
    )

    const usable: Display[] = []
    for (const d of candidates) {
      if (await probeBrightness(d.bus)) usable.push(d)
      // console.log, not console.info: GJS maps info to G_LOG_LEVEL_INFO, which
      // GLib drops unless G_MESSAGES_DEBUG is set, so those lines never reach the
      // journal. console.log maps to G_LOG_LEVEL_MESSAGE and is always shown.
      else console.log(`ddc: ${d.model} on bus ${d.bus} does not answer DDC — skipping`)
    }

    // Set before readProfile: `gamut` is computed from this list.
    setDisplays(usable)
    await readProfile()
    setReady(true)
    console.log(`ddc: ready — ${usable.map((d) => `${d.model}@${d.bus}`).join(", ") || "none"}`)
  } catch (e) {
    console.error("ddc: detect failed, no monitor controls available —", e)
  }
}

const pendingWrite = new Map<number, { cancel(): void }>()

export function setDisplayBrightness(bus: number, value: number) {
  const clamped = Math.max(0, Math.min(100, Math.round(value)))
  // Optimistic — the UI tracks the pointer immediately rather than waiting on a
  // ~150ms I²C round trip.
  setBrightness((prev) => ({ ...prev, [bus]: clamped }))

  pendingWrite.get(bus)?.cancel()
  pendingWrite.set(
    bus,
    timeout(WRITE_DEBOUNCE_MS, () => {
      pendingWrite.delete(bus)
      ddc(bus, "setvcp", BRIGHTNESS, String(clamped)).catch((e) =>
        console.error(`ddc: brightness write failed on bus ${bus} —`, e),
      )
    }),
  )
}

export async function setDisplayProfile(value: number) {
  const display = gamut.get()
  if (!display) return
  setProfile(value)
  try {
    await ddc(display.bus, "setvcp", GAMEVISUAL, `0x${value.toString(16).padStart(2, "0")}`)
    // A GameVisual mode is a container, not a single setting: switching it also
    // rewrites brightness, the colour preset and the gamut in one go. Everything
    // cached for this bus is stale now, so re-read rather than trust the write.
    await readBrightness(display.bus)
    await readProfile()
  } catch (e) {
    console.error("ddc: profile write failed —", e)
    await readProfile()
  }
}

// Wired to a button, never a timer: reconciling costs 0.08–0.4s of serialised
// I²C per monitor, and an OSD-side change is the only thing it can discover.
//
// Escalates to a full re-detect when the list looks wrong. A monitor that was
// asleep when init() ran is missing from `displays` altogether, and re-reading
// a list it is not in can never bring it back — which made this button a no-op
// in exactly the case it exists for.
export async function refresh() {
  const known = displays.get()
  let intact = known.length > 0
  for (const d of known) if (!(await readBrightness(d.bus))) intact = false

  if (!intact) return init()

  await readProfile()
}
