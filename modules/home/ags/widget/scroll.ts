import { Gtk } from "ags/gtk4"

// Scroll-to-adjust for bar indicators.
//
// A wheel notch arrives as dy = ±1.0 from a discrete mouse, but as a stream of
// fractions from a high-resolution one — and the PRO X reports hi-res. Acting on
// the sign alone would slam the value from end to end in a flick, so deltas are
// accumulated and spent a whole notch at a time.
//
// `step` is called with a signed notch count: +1 for one notch up, -1 for down.
export function wheel(self: Gtk.Widget, step: (notches: number) => void) {
  const controller = new Gtk.EventControllerScroll({
    flags: Gtk.EventControllerScrollFlags.VERTICAL,
  })

  let accumulated = 0

  controller.connect("scroll", (_source, _dx, dy) => {
    accumulated += dy
    while (accumulated <= -1) {
      accumulated += 1
      step(1) // dy is negative upward
    }
    while (accumulated >= 1) {
      accumulated -= 1
      step(-1)
    }
    return true // stop here rather than letting the bar scroll behind us
  })

  self.add_controller(controller)
}
