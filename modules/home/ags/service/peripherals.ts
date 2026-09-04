import Gio from "gi://Gio"
import { readFile } from "ags/file"
import { createState } from "ags"
import { interval } from "ags/time"

// Battery for wireless peripherals — the PRO X mouse today, whatever else the
// kernel exposes later. Scoped to `scope = Device` on purpose: a laptop's own
// battery is scope System and stays with the WezTerm tabline on cordyceps, so
// the two never report the same cell twice.
//
// Nothing here can see the BlackShark V3 Pro. Razer reports battery over a
// vendor HID protocol rather than the standard usage page, so the kernel builds
// no power_supply node for it; HeadsetControl 4.0.0 ships no Razer devices at
// all and OpenRazer 3.12.4 has no BlackShark entries. It would take a custom
// hidraw reader plus udev rules to reach it.

export type Peripheral = {
  id: string
  model: string
  capacity: number
  charging: boolean
  isMouse: boolean
}

const POWER_SUPPLY = "/sys/class/power_supply"

// Peripherals report over their own radio link and move by single digits an
// hour; polling faster would only spend wakeups.
const POLL_MS = 60_000

const [peripherals, setPeripherals] = createState<Peripheral[]>([])
export { peripherals }

// sysfs attributes are optional and racy — a device can vanish between the
// directory listing and the read — so a miss means "skip it this round", not a
// failure worth surfacing.
function attr(path: string): string | null {
  try {
    return readFile(path).trim()
  } catch {
    return null
  }
}

function listDir(path: string): string[] {
  const names: string[] = []
  try {
    const e = Gio.File.new_for_path(path).enumerate_children(
      "standard::name",
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
    let info = e.next_file(null)
    while (info !== null) {
      names.push(info.get_name())
      info = e.next_file(null)
    }
  } catch {
    // No such directory: a host with nothing of this kind attached.
  }
  return names
}

// A power_supply node says nothing about what the device *is*, so follow its
// `device` link to the HID node and ask whether it reports relative axes. That
// is what separates a mouse from a headset or keyboard, and it beats matching on
// model_name, which changes with every product Logitech ships.
function isMouse(base: string): boolean {
  return listDir(`${base}/device/input`).some((input) => {
    const rel = attr(`${base}/device/input/${input}/capabilities/rel`)
    return !!rel && parseInt(rel, 16) !== 0
  })
}

// createState compares by reference, so handing it a freshly built array would
// repaint every bar once a minute even when no number moved.
let last = ""

function sample() {
  const found: Peripheral[] = []

  for (const id of listDir(POWER_SUPPLY)) {
    const base = `${POWER_SUPPLY}/${id}`
    if (attr(`${base}/type`) !== "Battery") continue
    if (attr(`${base}/scope`) !== "Device") continue

    const capacity = Number(attr(`${base}/capacity`))
    if (!Number.isFinite(capacity)) continue

    found.push({
      id,
      model: attr(`${base}/model_name`) || id,
      capacity,
      charging: attr(`${base}/status`) === "Charging",
      isMouse: isMouse(base),
    })
  }

  const key = JSON.stringify(found)
  if (key === last) return
  last = key
  setPeripherals(found)
}

let timer: ReturnType<typeof interval> | null = null

export function init() {
  if (timer) return
  timer = interval(POLL_MS, sample)
}
