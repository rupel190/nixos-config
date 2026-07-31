import { createPoll } from "ags/time"
import { execAsync } from "ags/process"
import GLib from "gi://GLib"

const CALENDAR_URL = "https://calendar.proton.me/"

// The `ags init` template does createPoll("", 1000, "date") — that forks the
// `date` binary once a second, per monitor, for the entire session. GLib formats
// the same string in-process for free.
const fmt = (pattern: string) => GLib.DateTime.new_now_local().format(pattern)!

function openCalendar() {
  // Handed to the compositor rather than run as execAsync("zen …") directly: AGS
  // runs as a systemd user unit with KillMode=mixed, so anything it forks sits in
  // that unit's cgroup and dies on `systemctl --user restart ags` — which is the
  // normal edit loop for this config. `dispatch exec` spawns from Hyprland
  // instead, so the browser outlives the bar and still picks up window rules.
  execAsync(["hyprctl", "dispatch", "exec", `zen ${CALENDAR_URL}`]).catch((e) =>
    console.error("Clock: could not open calendar —", e),
  )
}

export default function Clock() {
  // Separate accessors rather than one preformatted string. createPoll only
  // notifies subscribers when the value actually changes, so the HH:MM label
  // repaints once a minute despite being sampled every second — and the seconds
  // tick on their own without dragging the rest of the widget along.
  const hm = createPoll(fmt("%H:%M"), 1000, () => fmt("%H:%M"))
  const sec = createPoll(fmt("%S"), 1000, () => fmt("%S"))
  const date = createPoll(fmt("%a %d %b"), 60_000, () => fmt("%a %d %b"))

  return (
    <button class="Clock" onClicked={openCalendar} tooltipText="Open Proton Calendar">
      <box>
        <label class="hm" label={hm} />
        <label class="sec" label={sec} />
        <label class="sep" label="·" />
        <label class="date" label={date} />
      </box>
    </button>
  )
}
