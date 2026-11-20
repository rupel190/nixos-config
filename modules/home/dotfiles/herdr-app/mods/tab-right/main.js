import { View, div } from "gpui-kit";
import { spaces, run, props, closeOverlay } from "herdr";

// Moves the active tab one place; mod.open is the only way a key reaches a mod.
const STEP = 1;

export default class TabRight extends View {
  init() {
    const tabs = spaces().find(s => s.active)?.tabs ?? [];
    const i = tabs.findIndex(t => t.active);
    if (i >= 0 && tabs[i + STEP]) run("tab.move", { id: tabs[i].id, index: i + STEP + 1 });
    const overlay = props()?.overlay;
    if (overlay) closeOverlay(overlay);
  }

  render() { return div(); }
}
