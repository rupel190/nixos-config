import Gio from "gi://Gio"
import { readFile } from "ags/file"

export const POWER_SUPPLY = "/sys/class/power_supply"

// sysfs attributes are optional and racy — a device can vanish between the
// directory listing and the read — so a miss means "skip it this round", not a
// failure worth surfacing.
export function attr(path: string): string | null {
  try {
    return readFile(path).trim()
  } catch {
    return null
  }
}

export function listDir(path: string): string[] {
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
