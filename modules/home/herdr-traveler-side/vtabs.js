import { View, div, svg, image } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { agents, spaces, panes, run, openOverlay, theme, appHome, readTextFile } from "herdr";
import { assignJobs, jobIn, portraitPath, tabNames } from "./lib.js";

const JOBS_FILE = `${appHome()}/mods/traveler-agents/jobs.json`;

// traveler's tab strip turned on its side: the active space's tabs as a list in the sidebar.
export default class VerticalTabs extends View {
  init(_props, cx) {
    this.pressed = null;
    this.jobs = {};
    cx.spawn(async (cx) => {
      const text = await readTextFile(JOBS_FILE).catch(() => null);
      try { const parsed = JSON.parse(text); if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) this.jobs = parsed; } catch {}
      cx.notify();
    });
  }

  render() {
    const t = theme();
    const space = spaces().find(p => p.active);
    const shown = space?.tabs ?? [];
    const assigned = assignJobs(tabNames(spaces(), agents()), this.jobs);
    const stop = (_e, cx) => cx.stop_propagation();
    const item = (c, i) => {
      const program = panes().find(p => p.tab === c.id && p.program?.agent)?.program ?? panes().find(p => p.tab === c.id)?.program;
      const name = /^tb\d+$/.test(c.name) ? program?.name ?? "Terminal" : c.name;
      const portrait = portraitPath(jobIn(c.name, assigned));
      return h_flex().id(`tab-${c.id}`).w_full().h(48).px(8).gap(7).items_center().flex_none().text_size(12.8)
        .border(1).border_color(c.active ? t.accent : t.border).bg(c.active ? t.raised : `${t.surface}c8`).text_color(c.active ? t.foreground : t.muted)
        .cursor_pointer().hover(s => s.bg(t.hover))
        .on_mouse_down("left", (e, cx) => { cx.stop_propagation(); this.pressed = i; if (e.click_count === 2) run("tab.rename", { id: c.id }); })
        .on_mouse_up("left", () => {
          const from = this.pressed; this.pressed = null;
          if (from !== null && from !== i) run("tab.move", { id: shown[from].id, index: space.tabs.findIndex(x => x.id === c.id) + 1 });
          else run("tab.select", { id: c.id });
        })
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); openOverlay({ mod: "menu", kind: "popup", width: 200, props: { tab: "tab", target: { id: c.id, space: space.id } } }); })
        .when(Boolean(portrait), el => el.child(image(portrait).size(44).flex_none()))
        .when(!portrait && Boolean(program?.icon), el => el.child(program.tint ? svg(program.icon).size(14).text_color(t.muted) : image(program.icon).size(14)))
        .child(div().flex_1().min_w(0).truncate().child(c.zoomed ? `${name} Z` : name))
        .when(c.status === "working", el => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
        .when(c.status === "blocked" || c.status === "done", el => el.child(div().size(6).rounded(3).flex_none().bg(t[c.status])))
        .when(c.active, el => el.child(div().id(`close-${c.id}`).flex_none().text_color(t.dim).on_mouse_down("left", stop).on_click((_e, cx) => { cx.stop_propagation(); run("tab.close", { id: c.id }); }).child(svg("mods/pane/close.svg").size(12))));
    };
    return v_flex().size_full().min_h(0).text_size(13).text_color(t.foreground)
      .on_mouse_up("left", () => { this.pressed = null; })
      .child(h_flex().h(31).pl(16).pr(10).items_center().justify_between().flex_none().text_size(11.5).text_color(t.dim)
        .child("TABS")
        .child(div().id("tab-new").size(22).flex().items_center().justify_center().hover(s => s.bg(t.hover).text_color(t.foreground))
          .on_click(() => openOverlay({ mod: "new-menu", kind: "popup", width: 250, height: 512 })).child("+")))
      .child(v_flex().flex_1().min_h(0).gap(4).px(6).pb(6).overflow_y_scrollbar().children(shown.map(item)));
  }
}
