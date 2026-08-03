import app from "ags/gtk4/app"
import { createBinding, For } from "ags"
import type { Gdk, Gtk } from "ags/gtk4"
import style from "./style.scss"
import Bar from "./widget/Bar"
import { init as initDdc } from "./service/ddc"
import { init as initWindows } from "./service/windows"

app.start({
  css: style,
  main() {
    // Fired without awaiting: `ddcutil detect` takes ~3.4s and must not hold up
    // the bars appearing. The DDC widget renders an em dash until it resolves.
    initDdc()

    // Synchronous — reads the current client list straight off the Hyprland IPC
    // socket, then keeps itself current from its `event` signal.
    initWindows()

    // One bar per connected monitor, rebuilt whenever that set changes.
    //
    // Deliberately not `app.get_monitors().map(Bar)` (what `ags init` scaffolds):
    // that is a one-shot snapshot, and the snapshot is what makes a bar hop
    // screens. Powering a monitor off drops its wl_output; the compositor closes
    // the layer surface bound to it, but the GtkWindow itself is still alive and
    // gets remapped with no output set — so the compositor parks it on whichever
    // screen is focused and you end up with two bars stacked on one monitor.
    //
    // `monitors` is a notify-able property: App's constructor wires it to the
    // GdkDisplay monitor list's `items-changed`. Binding to it means a bar is
    // destroyed with the output it belonged to and a fresh one is built when
    // that output comes back.
    //
    // `For` is called rather than written as JSX because this file has to stay
    // `app.ts` — it is the entry point the `ags` CLI looks for. Its return value
    // (a Fragment holding the windows) is deliberately dropped: each window
    // keeps itself alive by registering with `app`, and the subscription is
    // owned by the root scope, which lives until shutdown.
    For({
      each: createBinding(app, "monitors"),

      // No `id`: the default keys by object identity, which is what we want.
      // Keying by connector instead would look tidier and be wrong — a
      // re-plugged DP-1 is a *new* GdkMonitor, and matching it to the old key
      // would keep the existing window pointed at the invalidated one.
      children: (gdkmonitor: Gdk.Monitor) => Bar(gdkmonitor),

      // Not passing this is a silent leak. `For` falls back to
      // `env.defaultCleanup` when `cleanup` is undefined, and gnim's GTK4
      // runtime never overrides that no-op (only the GTK3 and GNOME ones do) —
      // so the orphaned window would survive exactly as it does today.
      // The cast is unavoidable: gnim types every element as `JSX.Element`,
      // which is just `GObject.Object`, so `destroy` is not visible on it.
      cleanup: (win) => (win as Gtk.Window).destroy(),
    })
  },
})
