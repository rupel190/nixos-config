import { div, image } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { agents, run, setAgentOrder, spaces, theme } from "herdr";
import Cards from "./cards.js";
import { assignJobs, jobIn, portraitPath, tabNames } from "./lib.js";

const RANK = ["blocked", "working", "done"];

// traveler's agents with the idle ones folded so more fit: a card for whoever is busy or waiting,
// a row for a warm idle session (HP, MP), a name in two columns for a cold one.
export default class Agents extends Cards {
  shell(a, t, look) {
    return look
      .id(`agent-${a.address}`).items_center().min_w(0)
      .bg(`${t.surface}c8`).border(1).border_color(a.focused ? t.accent : t.border)
      .cursor_pointer().hover(s => s.bg(t.hover))
      .tooltip(`${a.space_name} / ${a.tab_name}`)
      .on_click(() => run("agent.focus", { terminal: a.address }));
  }

  face(a, size) {
    const src = portraitPath(jobIn(a.tab_name, this.assigned)) ?? a.program?.icon;
    return src ? image(src).size(size).flex_none() : div().size(size).flex_none();
  }

  meter(value, color, t) {
    return div().w_full().h(4).bg(t.raised)
      .when(value !== null, el => el.child(div().h_full().w(`${value}%`).bg(color)));
  }

  row(a, c, t) {
    return this.shell(a, t, h_flex()).w_full().flex_none().h(36).px(6).gap(7)
      .child(this.face(a, 30))
      .child(div().flex_1().min_w(0).truncate().text_size(12.5).child(a.tab_name || a.address))
      .child(v_flex().w(56).flex_none().gap(3).child(this.meter(c.hp, t.accent, t)).child(this.meter(c.mp, t.solid, t)))
      .child(div().w(26).flex_none().text_size(11).text_right().child(`${Math.ceil(c.hp * 0.58)}m`));
  }

  chip(a, c, t) {
    return this.shell(a, t, h_flex()).w(121).flex_none().h(28).px(4).gap(5)
      .child(this.face(a, 22).opacity(0.5))
      .child(v_flex().flex_1().min_w(0).gap(2)
        .child(div().w_full().min_w(0).truncate().text_size(11).text_color(t.muted).child(a.tab_name || a.address))
        .when(Boolean(c), el => el.child(this.meter(c.mp, t.solid, t).h(2))));
  }

  label(text, list, t) {
    return h_flex().w_full().flex_none().h(22).px(4).gap(8).items_center().text_size(10.5).text_color(t.dim)
      .child(`${text} ${list.length}`)
      .child(div().flex_1().h(1).bg(t.border));
  }

  chips(list, t) {
    return h_flex().w_full().flex_none().flex_wrap().gap(4).children(list.map(a => this.chip(a, this.data(a), t)));
  }

  data(a) {
    return this.cache[a.address] ?? this.remote[a.address] ?? null;
  }

  render(cx) {
    const t = theme();
    const all = agents();
    this.assigned = assignJobs(tabNames(spaces(), all), this.jobs);
    const fresh = all.filter(a => !this.seen.has(a.address));
    fresh.forEach(a => this.seen.add(a.address));
    if (fresh.length > 0) { this.load(cx); this.loadRemote(cx); }

    const busy = RANK.flatMap(s => all.filter(a => a.status === s));
    const idle = all.filter(a => !RANK.includes(a.status))
      .sort((x, y) => (this.data(y)?.repliedAt ?? 0) - (this.data(x)?.repliedAt ?? 0));
    const hp = a => this.data(a)?.hp ?? null;
    const warm = idle.filter(a => hp(a) > 0);
    const cold = idle.filter(a => hp(a) === 0);
    const unknown = idle.filter(a => hp(a) === null);
    setAgentOrder([...busy, ...warm, ...cold, ...unknown].map(a => a.address));

    const now = Math.floor(Date.now() / 1000);
    return v_flex().id("traveler").size_full().min_h(0).text_color(t.foreground).text_size(13)
      .child(h_flex().h(30).px(12).items_center().justify_between().flex_none().text_size(11.5).text_color(t.muted)
        .bg(t.chrome).border_y(1).border_color(t.border)
        .child("AGENTS").child(div().text_color(t.dim).child(String(all.length))))
      .child(v_flex().flex_1().min_h(0).gap(5).p(6).overflow_y_scrollbar()
        .children(busy.map(a => this.card(a, now, t)))
        .when(warm.length > 0, el => el.child(this.label("IDLE", warm, t)))
        .children(warm.map(a => this.row(a, this.data(a), t)))
        .when(cold.length > 0, el => el.child(this.label("COLD", cold, t)).child(this.chips(cold, t)))
        .when(unknown.length > 0, el => el.child(this.label("NO REPLY YET", unknown, t)).child(this.chips(unknown, t)))
        .when(all.length === 0, el => el.child(div().p(8).text_size(12).text_color(t.dim).child("No agents"))));
  }
}
