import app from "ags/gtk4/app"
import { Astal, Gdk, Gtk } from "ags/gtk4"
import Clock from "./Clock"

export default function Bar(gdkmonitor: Gdk.Monitor) {
  // Anchoring all three edges makes the window span the monitor width; TOP alone
  // would size it to its content and float as an island. Full width is what an
  // indicator-heavy bar wants — it gives the start/end slots somewhere to grow.
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible
      // Unique per monitor: `ags request`/toggle addresses windows by name, and
      // three windows sharing the name "bar" would be ambiguous.
      name={`bar-${gdkmonitor.connector}`}
      class="Bar"
      gdkmonitor={gdkmonitor}
      // EXCLUSIVE reserves the bar's height in the layer-shell surface, so
      // tiled windows start below it instead of underneath.
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox class="bar-inner">
        {/* start — reserved for workspaces */}
        <box $type="start" halign={Gtk.Align.START} />

        <box $type="center">
          <Clock />
        </box>

        {/* end — reserved for the ddcutil display indicator + tray */}
        <box $type="end" halign={Gtk.Align.END} />
      </centerbox>
    </window>
  )
}
