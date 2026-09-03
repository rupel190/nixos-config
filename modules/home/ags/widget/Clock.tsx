import { createPoll } from "ags/time"
import { execAsync } from "ags/process"
import { Gdk, Gtk } from "ags/gtk4"
import GLib from "gi://GLib"

const CALENDAR_URL = "https://calendar.proton.me/"

// The `ags init` template does createPoll("", 1000, "date") — that forks the
// `date` binary once a second, per monitor, for the entire session. GLib formats
// the same string in-process for free.
const fmt = (pattern: string) => GLib.DateTime.new_now_local().format(pattern)!

// Handed to the compositor rather than run as execAsync directly: AGS runs as a
// systemd user unit with KillMode=mixed, so anything it forks sits in that unit's
// cgroup and dies on `systemctl --user restart ags` — the normal edit loop here.
// That kills a browser, and it kills the wl-copy daemon still holding the
// selection. Spawning from Hyprland puts both outside the unit.
//
// The payload is a Lua expression, not a dispatcher line: Hyprland's IPC parser
// is Lua-only on main, so the old `dispatch exec <cmd>` form is a silent syntax
// error. JSON.stringify doubles as a Lua string literal, same as keybinds.nix.
function hyprExec(cmd: string) {
  return execAsync([
    "hyprctl",
    "dispatch",
    `hl.dsp.exec_cmd(${JSON.stringify(cmd)})`,
  ]).catch((e) => console.error(`Clock: could not run \`${cmd}\` —`, e))
}

const openCalendar = () => hyprExec(`zen ${CALENDAR_URL}`)
const copy = (text: string) => hyprExec(`wl-copy -- ${text}`)

// Works because GtkButton binds its own click gesture to the primary button
// only, so a secondary press is never claimed on the way up and the label — the
// pick target, since GtkWidget:can-target is true by default — keeps it.
function onSecondaryClick(self: Gtk.Widget, handler: () => void) {
  const gesture = new Gtk.GestureClick({ button: Gdk.BUTTON_SECONDARY })
  gesture.connect("pressed", handler)
  self.add_controller(gesture)
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
      tooltipText="Click for Proton Calendar · right-click the time or date to copy it"
    >
      <box>
        <label
          class="hm"
          label={hm}
          $={(self) => onSecondaryClick(self, () => copy(hm.get()))}
        />
        <label class="sep" label="·" />
        {/* Copied as ISO 8601 rather than the `%a %d %b` on screen — the bar
            wants a glanceable date, a paste target wants a sortable one. */}
        <label
          class="date"
          label={date}
          $={(self) => onSecondaryClick(self, () => copy(fmt("%Y-%m-%d")))}
        />
      </box>
    </button>
  )
}
