import { Gtk } from "ags/gtk4"
import { createPoll } from "ags/time"
import GLib from "gi://GLib"

// The `ags init` template does createPoll("", 1000, "date") — that forks the
// `date` binary once a second, per monitor, for the entire session. GLib formats
// the same string in-process for free.
const fmt = (pattern: string) => GLib.DateTime.new_now_local().format(pattern)!

const TIME = "%H:%M:%S"
const DATE = "%a %d %b"

export default function Clock() {
  const time = createPoll(fmt(TIME), 1000, () => fmt(TIME))
  // The date only changes at midnight, so it has no business on the 1s tick.
  // createPoll only notifies subscribers when the value actually differs, so the
  // label repaints once a day regardless.
  const date = createPoll(fmt(DATE), 60_000, () => fmt(DATE))

  return (
    <menubutton class="Clock">
      <box spacing={10}>
        <label class="time" label={time} />
        <label class="date" label={date} />
      </box>
      <popover>
        <Gtk.Calendar />
      </popover>
    </menubutton>
  )
}
