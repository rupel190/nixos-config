import app from "ags/gtk4/app"
import style from "./style.scss"
import Bar from "./widget/Bar"
import { init as initDdc } from "./service/ddc"

app.start({
  css: style,
  main() {
    // Fired without awaiting: `ddcutil detect` takes ~3.4s and must not hold up
    // the bars appearing. The DDC widget renders an em dash until it resolves.
    initDdc()

    // One bar per connected monitor. This is a snapshot taken at startup: a
    // monitor hotplugged later (HDMI-A-1, the AVR, which mirrors DP-1) gets no
    // bar until the service restarts. Acceptable for now — revisit with a
    // monitors listener if it starts to bite.
    app.get_monitors().map(Bar)
  },
})
