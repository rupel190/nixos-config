import { View, div, svg, image } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, run, openOverlay, theme, window, shared, layout, settings } from "herdr";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// traveler's top bar with the spaces where the tabs were; the side-panel buttons and window
// buttons stay on the right, and the per-space panel memory is traveler-tabs' own.
export default class SpaceBar extends View {
  init(_props, cx) {
    this.pressed = null;
    this.panels = JSON.parse(localStorage.getItem("panels") ?? "{}");
  }

  syncPanel(space, panel, body, enabled) {
    if (!space || !panel) return;
    const now = panel.hidden ? null : body?.active ?? null;
    if (space.id !== this.space) {
      const first = this.space === undefined;
      this.space = space.id; this.pending = null;
      if (!(first && !(space.id in this.panels))) {
        const stored = this.panels[space.id] ?? null, want = enabled.includes(stored) ? stored : null;
        if (want !== now) {
          this.pending = { want, until: Date.now() + 1000 };
          if (want) { run("layout.select", { stack: "panel-body", child: want }); run("layout.show", { id: "panel" }); }
          else run("layout.hide", { id: "panel" });
          return;
        }
      }
    }
    if (this.pending) {
      if (this.pending.want !== now && Date.now() < this.pending.until) return;
      this.pending = null;
    }
    if (this.panels[space.id] === now) return;
    this.panels[space.id] = now;
    localStorage.setItem("panels", JSON.stringify(this.panels));
  }

  render() {
    const t = theme();
    const all = spaces(), space = all.find(p => p.active);
    const stop = (_e, cx) => cx.stop_propagation();
    const button = (id, label, action) => div().id(id).size(26).flex_none().flex().items_center().justify_center().text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", stop).on_click(action).child(label);
    const chip = (sp, i) => {
      return h_flex().id(`space-${sp.id}`).h(48).px(8).gap(7).items_center().flex_none().text_size(12.8)
        .border(1).border_color(sp.active ? t.border : t.chrome).bg(sp.active ? t.raised : t.chrome).text_color(sp.active ? t.foreground : t.muted)
        .cursor_pointer().hover(s => s.bg(t.hover))
        .on_mouse_down("left", (_e, cx) => { cx.stop_propagation(); this.pressed = i; })
        .on_mouse_up("left", () => {
          const from = this.pressed; this.pressed = null;
          if (from !== null && from !== i) run("space.move", { id: all[from].id, index: i + 1 });
          else run("space.select", { id: sp.id });
        })
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); openOverlay({ mod: "menu", kind: "popup", width: 200, height: 260, props: { tab: "space", target: { id: sp.id } } }); })
        .child(div().text_color(t.dim).child(String(i + 1)))
        .child(div().max_w(170).truncate().child(sp.name))
        .when(sp.status === "working", el => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
        .when(sp.status === "blocked" || sp.status === "done", el => el.child(div().size(6).rounded(3).bg(t[sp.status])));
    };
    const root = layout(), sidebar = find(root, "sidebar"), w = window();
    const lightsPadding = w?.platform === "macos" && w.titlebar === "none" && !w.fullscreen && root?.traffic_lights
      ? Math.max(10, (root.traffic_lights[0] + 64) / settings().zoom - (sidebar?.hidden ? 0 : sidebar?.size?.px ?? 0))
      : 10;
    const panel = find(root, "panel"), body = find(root, "panel-body");
    const enabled = shared("workspace.panels") ?? ["files", "changes"];
    this.syncPanel(space, panel, body, enabled);
    const panelButton = (id, label, icon) => {
      const on = panel && !panel.hidden && body?.active === id;
      return h_flex().id(`panel-${id}`).h(26).px(8).gap(5).flex_none().items_center()
        .text_size(12).bg(on ? t.selected : t.chrome).text_color(on ? t.foreground : t.muted)
        .hover(s => s.bg(t.hover)).on_mouse_down("left", stop)
        .on_click(() => {
          if (on) run("layout.hide", { id: "panel" });
          else { run("layout.select", { stack: "panel-body", child: id }); run("layout.show", { id: "panel" }); }
        }).child(image(icon).size(20).flex_none()).child(label);
    };
    return h_flex().size_full().min_w(0).px(10).pl(lightsPadding).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
      .child(h_flex().id("space-scroll").flex_1().min_w(0).h_full().items_center().gap(3).overflow_x_scrollbar().children(all.map(chip)))
      .child(button("space-new", "+", () => run("space.new")))
      .when(enabled.includes("files"), el => el.child(panelButton("files", "Files", "mods/traveler-tabs/art/files.png")))
      .when(enabled.includes("changes"), el => el.child(panelButton("changes", "Changes", "mods/traveler-tabs/art/changes.png")))
      .when(w?.buttons, el => el.child(button("minimize", w.platform === "windows" ? svg("mods/traveler-tabs/win-min.svg").size(16) : "−", () => run("window.minimize")))
        .child(button("maximize", w.platform === "windows" ? svg(`mods/traveler-tabs/${w.maximized ? "win-restore" : "win-max"}.svg`).size(16) : "□", () => run("window.maximize")))
        .child(button("close-window", w.platform === "windows" ? svg("mods/traveler-tabs/win-close.svg").size(16) : svg("mods/pane/close.svg").size(13), () => run("window.close"))));
  }
}
