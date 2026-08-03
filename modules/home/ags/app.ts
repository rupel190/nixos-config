import app from "ags/gtk4/app"
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

    // One bar per connected monitor. This is a snapshot taken at startup: a
    // monitor hotplugged later (HDMI-A-1, the AVR, which mirrors DP-1) gets no
    // bar until the service restarts. Acceptable for now — revisit with a
    // monitors listener if it starts to bite.
    app.get_monitors().map(Bar)
  },
})
