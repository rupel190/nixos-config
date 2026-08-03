import app from "ags/gtk4/app"
import { Astal, Gdk, Gtk } from "ags/gtk4"
import Clock from "./Clock"
import DisplayIndicator from "./Display"
import Windows from "./Windows"

export default function Bar(gdkmonitor: Gdk.Monitor) {
  // Anchoring all three edges spans the monitor width; TOP alone would size the
  // window to its content and float as an island. Full width is what an
  // indicator-heavy bar wants — it gives the start/end slots room to grow.
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible
      // Unique per monitor: `ags toggle`/`ags request` address windows by name,
      // and three windows sharing the name "bar" would be ambiguous.
      name={`bar-${gdkmonitor.connector}`}
      // Shared across all three bars on purpose — this is the layer-shell
      // namespace Hyprland matches on to frost what is behind the bar. See the
      // layerrule in modules/home/hyprland/config.nix.
      namespace="ags-bar"
      class="Bar"
      gdkmonitor={gdkmonitor}
      // EXCLUSIVE reserves the bar's height in the layer-shell surface, so tiled
      // windows start below it rather than underneath.
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox class="bar-inner">
        <box $type="start" halign={Gtk.Align.START}>
          <Windows />
        </box>

        <box $type="center">
          <Clock />
        </box>

        {/* end — DDC monitor controls; tray still to come */}
        <box $type="end" halign={Gtk.Align.END}>
          <DisplayIndicator />
        </box>
      </centerbox>
    </window>
  )
}
