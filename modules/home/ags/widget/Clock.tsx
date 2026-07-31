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
  // Still sampled every second despite only rendering HH:MM. createPoll notifies
  // subscribers only when the value actually changes, so this repaints once a
  // minute either way — whereas a literal 60_000 interval is unanchored to the
  // wall clock and would show a stale minute for up to 59s after the rollover.
  const hm = createPoll(fmt("%H:%M"), 1000, () => fmt("%H:%M"))
  const date = createPoll(fmt("%a %d %b"), 60_000, () => fmt("%a %d %b"))

  // focusable=false kills the focus ring. GTK4 draws focus with `outline`, and
  // Catppuccin paints it in the teal accent — so clicking the clock left a bright
  // teal box around it, since focus-on-click is true by default on buttons.
  // Nothing on a bar should be a keyboard focus target anyway.
  return (
    <button
      class="Clock"
      focusable={false}
      onClicked={openCalendar}
      tooltipText="Open Proton Calendar"
    >
      <box>
        <label class="hm" label={hm} />
        <label class="sep" label="·" />
        <label class="date" label={date} />
      </box>
    </button>
  )
}
