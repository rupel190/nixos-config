import { View, div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { agents, spaces, panes, terminals, props, run, exec, setAgentOrder, knownAgents, appHome } from "herdr";
import { ink, SLOT_W, SLOT_H, SCREEN, CATS, RUGS, r, icon, txt, hash, rng, pick, look, deskLook, clutter, standing, cat } from "./art.js";
import { rank, modelName, hunger, ago, dress, sitter, loafer, stander, walker, bench, laptop, ramen, pile, tower, meter, cobweb, chairWeb, vacated, headstone, fence, yardGate } from "./people.js";
import { demoWorld } from "./demo.js";

// A building: every space is a floor, every tab a computer, every agent a person. Nothing here
// may pretend agents interact, and hunger, rank and death all come from real data.
// Desks at 2.5/3 of Office's size. People stay on whole pixels: their rows gap at fractions.
const K = 2.5 / 3, S = 3, INTERN_S = 2;
const LIGHTS = 40, ROOF = 60, GROUND = 70, WALL_H = 40, SLAB = 8;
const WALK = 0.11, CAT_WALK = 0.07;
const FURNITURE = ["cooler", "shelf", "window", "plant"];
const STONE_W = 96, STONE_H = 106, YARD_TOP = 96, FENCE = 40;
const FACTS_MS = 20000;
const URGENT = { blocked: 4, done: 3, working: 2, idle: 1 };
const busy = (a) => a.status === "working" || a.status === "blocked";
const q = (v) => Math.round(v * K);
const DVD = ["#e05a8a", "#5ab0e0", "#e0c040", "#7ee0a0", "#c08ae0", "#f08a4a"];
const POSE = { low: { pose: "loaf", beats: 8 }, medium: { pose: "sit", slump: true, beats: 6 }, high: { pose: "sit", beats: 4 }, xhigh: { pose: "stand", beats: 2 }, max: { pose: "stand", beats: 2, sweat: true } };
// Every redraw redraws the whole window and a native loop asks for 30 a second, so all motion is
// worked out here, on one slow beat: 2 redraws a second while anyone works or walks, else 1.
const BEAT = 250;
const swing = (t, period, from, to) => { const u = (t % period) / period; return Math.round(from + (to - from) * (u < 0.5 ? u * 2 : 2 - u * 2)); };
const ZS = ["z", "zZ", "zZz", ""];

// Walls, bays and floors: half of everything drawn, and it changes only with the size, the minute
// and the elevators. A retained view, rebuilt only then.
class Shell extends View {
  init(p) { this.p = p; }
  update(p) { this.p = p; }
  render() {
    const { W, H, floors, at, seed, doors, count, groundY } = this.p, hour = new Date(at).getHours();
    return div().absolute().left(0).top(0).w(W).h(H).bg("#6b7e96")
      .child(r(0, 0, W, ROOF, "#7f93ad"))
      .child(r(0, ROOF - 10, W, 10, "#6b3f1f"))
      .child(r(W - 90, 8, 44, 30, "#9c6436").border(2).border_color("#6b3f1f")).child(r(W - 84, 38, 4, 12, "#6b3f1f")).child(r(W - 60, 38, 4, 12, "#6b3f1f"))
      .child(v_flex().absolute().left(12).top(6).p(4).bg("#fbfbf6").border(2).border_color("#6b3f1f")
        .child(txt("THE BUILDING", 13)).child(txt(count, 10, "#6b5a4a")))
      .children(floors.map((f, i) => floorRoom(f, W, seed + i, hour, doors.includes(f.id), new Date(at))))
      .child(r(0, groundY, W, H - groundY, "#7c7c80")).child(r(0, groundY, W, 6, "#5c5c60"))
      .child(r(W - 70, H - 40, 34, 26, "#b0563a").border(2).border_color("#7a3020")).child(r(W - 58, H - 66, 8, 28, "#4f8a3a")).child(r(W - 72, H - 58, 34, 8, "#3c7030"));
  }
}

function floorRoom(f, W, seed, hour, open, now) {
  const R = rng(seed), top = f.y, h = f.h, kids = [];
  const [rug, edge] = RUGS[f.rug];
  kids.push(r(0, top, W, h, "#e2a465"));
  for (let y = WALL_H + 16; y < h - SLAB; y += 22) {
    kids.push(r(0, top + y, W, 2, "#c98a4f"));
    const off = Math.floor(R() * 80);
    for (let x = off - 80; x < W; x += 80) kids.push(r(x, top + y - 20, 2, 20, "#c98a4f"));
  }
  kids.push(r(f.bay, top + WALL_H, W - f.bay, h - WALL_H - SLAB, `${rug}55`));
  kids.push(r(0, top, W, WALL_H, "#c3cfe0"), r(0, top + 22, W, WALL_H - 22, "#8796b0"), r(0, top + 22, W, 3, "#6e7c96"), r(0, top + WALL_H - 3, W, 3, "#7a4a28"));
  kids.push(r(0, top + h - SLAB, W, SLAB, "#7a4a28"));
  kids.push(r(f.bay - 2, top, 2, h - SLAB, `${edge}`));
  // The elevator, opening while someone arrives.
  kids.push(r(14, top + 8, 48, 88, "#6b3f1f"));
  if (open) kids.push(r(18, top + 12, 40, 84, "#2b1a10"), r(18, top + 12, 6, 84, "#9a9aa6"), r(52, top + 12, 6, 84, "#9a9aa6"));
  else kids.push(r(18, top + 12, 19, 84, "#9a9aa6"), r(39, top + 12, 19, 84, "#9a9aa6"));
  kids.push(r(30, top + 2, 16, 6, "#2b2f3a"), r(36, top + 3, 4, 4, open ? "#f0c860" : "#6b5a4a"));
  kids.push(...furniture(f.furniture, f.bay - 70, top, h, R, hour, now, f.bay));
  return div().absolute().left(0).top(0).children(kids);
}

function furniture(kind, x, top, h, R, hour, now, bay) {
  if (bay < 120) return [];
  if (kind === "cooler") return [r(x + 12, top + 16, 22, 26, "#7fb8e8").border(2).border_color("#4a86c0"), r(x + 8, top + 42, 30, 46, "#d8dce4").border(2).border_color("#8a90a0"), r(x + 16, top + 50, 10, 4, "#4a86c0")];
  if (kind === "shelf") {
    const books = ["#7a2f2f", "#2f5a7a", "#3f6b3a", "#8a6a2a", "#5a3a7a", "#2f2f2f"];
    return [r(x, top + 8, 52, 88, "#9c6436").border(2).border_color("#6b3f1f"), r(x + 4, top + 34, 44, 2, "#6b3f1f"), r(x + 4, top + 62, 44, 2, "#6b3f1f"),
      ...[0, 1, 2].flatMap((row) => Array.from({ length: 6 }, (_, i) => { const t = 12 + Math.floor(R() * 8); return r(x + 5 + i * 7, top + 12 + row * 27 + 20 - t, 5, t, pick(R, books)); }))];
  }
  if (kind === "window") {
    const night = hour >= 19 || hour < 6, dusk = hour >= 17 && hour < 19, sky = night ? "#1d2547" : dusk ? "#f2a65a" : "#8fd0f5";
    return [r(x, top + 8, 56, 56, "#f4f4f0").border(3).border_color("#6b3f1f"), r(x + 4, top + 12, 48, 48, sky), r(x + 26, top + 12, 3, 48, "#f4f4f0"), r(x + 4, top + 34, 48, 3, "#f4f4f0"),
      ...(night ? [r(x + 36, top + 18, 8, 8, "#f4f0c8"), r(x + 12, top + 24, 2, 2, "#f4f0c8"), r(x + 16, top + 46, 2, 2, "#f4f0c8")] : dusk ? [] : [r(x + 10, top + 20, 16, 6, "#ffffff")])];
  }
  return [r(x + 10, top + 62, 30, 26, "#b0563a").border(2).border_color("#7a3020"), r(x + 22, top + 16, 6, 46, "#4f8a3a"), r(x + 6, top + 26, 20, 8, "#3c7030"), r(x + 26, top + 18, 22, 8, "#4f8a3a"), r(x + 4, top + 44, 22, 8, "#3c7030"), r(x + 28, top + 40, 20, 8, "#4f8a3a")];
}

// The dead: rebuilt only when someone new goes in the ground.
class Yard extends View {
  init(p) { this.p = p; this.hover = props()?.stone ?? null; }
  update(p) { this.p = p; }
  render(cx) {
    const { w, h, dead, now, perCol } = this.p, night = new Date(now).getHours();
    const dark = night >= 19 || night < 6;
    const col = (i) => Math.floor(i / perCol), row = (i) => i % perCol;
    const at = (i) => ({ x: FENCE + 24 + col(i) * STONE_W, y: YARD_TOP + row(i) * STONE_H });
    const hov = this.hover != null ? dead[this.hover] : null;
    const el = div().absolute().left(0).top(0).w(w).h(h).bg("#3f5234")
      .child(r(0, 0, w, YARD_TOP - 16, dark ? "#141a33" : "#a9b4bd"))
      .child(r(0, YARD_TOP - 16, w, 16, "#2f3f27"))
      .children(fence(h, 6))
      .child(yardGate(dead.length))
      .children(Array.from({ length: Math.floor(w * h / 18000) }, (_, i) => { const R = rng(i + 7); return r(Math.floor(R() * w), YARD_TOP + Math.floor(R() * (h - YARD_TOP)), 8, 3, "#4d6240"); }))
      .children(dead.map((d, i) => {
        const p = at(i);
        return headstone(d, now).id(`stone-${d.id}`).left(p.x).top(p.y).on_hover((on, cx) => {
          const next = on ? i : this.hover === i ? null : this.hover;
          if (next !== this.hover) { this.hover = next; cx.notify(); }
        });
      }));
    if (hov) {
      const p = at(this.hover), span = hov.born_ms && hov.last_ms ? Math.max(1, Math.round((hov.last_ms - hov.born_ms) / 86400000)) : null;
      el.child(v_flex().absolute().left(Math.min(p.x + 84, w - 262)).top(Math.min(p.y, h - 180)).w(250).p(8).gap(4).bg("#fff27a").border(2).border_color("#d8c440")
        .child(txt(hov.title ?? hov.project, 12, ink).truncate())
        .child(txt(`${hov.project}, ${[modelName(hov.model), hov.effort].filter(Boolean).join(" ") || "unknown model"}`, 11, "#6b5a4a").truncate())
        .child(txt(`${hov.turns} turns, ${span ?? "?"} days on the job`, 11, "#6b5a4a"))
        .child(txt(`Cause of death: ${hov.cause}`, 11, "#a8322a"))
        .when(!!hov.words, (e) => e.child(div().font_family("PxPlus IBM VGA 8x16").text_size(11).text_color(ink).child(`Last words: "${hov.words}"`))));
    }
    return el;
  }
}

export default class Building extends View {
  init(_p, cx) {
    const p = props() ?? {};
    this.size = { width: 1054, height: 1841 };
    this.seed = Math.floor(Math.random() * 2 ** 31);
    this.trips = {};
    this.bubbles = {};
    this.reports = {};
    this.doors = {};
    this.seats = {};
    this.fed = {};
    this.known = null;
    this.facts = null;
    this.hover = null;
    this.sy = p.sy ?? 0;
    this.px = p.px ?? 0;
    this.drag = null;
    this.n = 0;
    this.beat = 0;
    this.t = Date.now();
    this.people = [];
    this.floors = [];
    this.cat = { coat: pick(rng(this.seed), CATS), x: 200, floor: 0, left: false, until: 0, ms: 16 };
    this.shell = cx.new(Shell, this.shellProps());
    this.yard = cx.new(Yard, this.yardProps());
    cx.timer.every(BEAT, (cx) => {
      this.syncViews();
      this.beat++;
      const changed = this.tick();
      if (changed || this.beat % this.pace() === 0) cx.notify();
    });
    if (!p.demo) {
      this.loadFacts(cx);
      cx.timer.every(FACTS_MS, (cx) => this.loadFacts(cx));
    }
  }

  loadFacts(cx) {
    if (this.loading) return;
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const out = await exec(props()?.python ?? "python3", ["-I", `${appHome()}/mods/building/facts.py`]);
        this.facts = JSON.parse(out.stdout);
        cx.notify();
      } catch (e) { console.log(`building: facts failed: ${e}`); }
      this.loading = false;
    });
  }

  // ---- layout ---------------------------------------------------------------

  shellProps() {
    return { W: this.W ?? 400, H: this.H ?? 400, groundY: this.groundY ?? 0, floors: this.floors, at: Math.floor(Date.now() / 60000) * 60000, seed: this.seed,
      doors: Object.keys(this.doors).filter((k) => this.doors[k] > Date.now()), count: `${this.people.length} on the clock` };
  }

  yardProps() {
    const h = this.size.height, perCol = Math.max(1, Math.floor((h - YARD_TOP - 10) / STONE_H)), dead = this.dead ?? [];
    return { w: this.yardW ?? 400, h, dead, now: this.facts?.now ?? this.demoNow ?? 0, perCol };
  }

  syncViews() {
    const shell = this.shellProps(), yard = this.yardProps();
    const key = JSON.stringify([shell.W, shell.H, shell.at, shell.seed, shell.doors, shell.count, shell.floors.map((f) => [f.id, f.y, f.h])]);
    if (key !== this.shellKey) { this.shellKey = key; this.shell.set_props(shell); }
    const yk = JSON.stringify([yard.w, yard.h, yard.perCol, yard.dead.map((d) => d.id)]);
    if (yk !== this.yardKey) { this.yardKey = yk; this.yard.set_props(yard); }
  }

  world() {
    const p = props() ?? {};
    if (p.demo) {
      const d = demoWorld();
      this.demoNow = d.now;
      this.dead = d.dead;
      return d;
    }
    const facts = this.facts?.terminals ?? {}, list = agents(), terms = terminals(), now = Date.now();
    this.dead = this.facts?.dead ?? [];
    const merged = (a) => {
      const f = facts[a.address] ?? {};
      if (a.status === "working") this.fed[a.address] = now;
      const fed = Math.max(this.fed[a.address] ?? 0, f.fed_ms ?? 0) || null;
      return { ...a, ...f, status: a.status, title: a.title || f.title, fed, visitor: !!this.facts && !f.model && a.app !== "claude-code" };
    };
    const byAddr = new Map(list.map((a) => [a.address, a]));
    const parentOf = new Map(terms.filter((t) => t.parent).map((t) => [t.address, t.parent]));
    const tabOf = (addr) => {
      for (let i = 0, at = addr; i < 8 && at; i++, at = parentOf.get(at)) if (byAddr.has(at) && !parentOf.has(at)) return byAddr.get(at).tab;
      return null;
    };
    const interns = {}, leads = {};
    for (const t of terms) {
      if (!t.parent || t.state === "finished") continue;
      const tab = tabOf(t.address);
      if (tab) (interns[tab] ??= []).push({ address: t.address, status: t.status ?? "idle", title: t.title ?? "", ...facts[t.address], parent: t.parent });
    }
    for (const a of list) if (!parentOf.has(a.address)) (leads[a.tab] ??= []).push(merged(a));
    return {
      now,
      floors: spaces().map((s) => ({
        id: s.id, name: s.name,
        tabs: s.tabs.map((t) => ({
          id: t.id, name: t.name, space: s.id,
          people: (leads[t.id] ?? []).filter((a) => !a.retired),
          retired: (leads[t.id] ?? []).some((a) => a.retired),
          interns: interns[t.id] ?? [],
          terminal: panes().find((x) => x.tab === t.id && x.terminal)?.terminal ?? null,
        })),
      })),
    };
  }

  place(w, h) {
    const W = Math.max(200, w - LIGHTS), bay = W >= 460 ? 146 : 84, sw = q(SLOT_W), sh = q(SLOT_H);
    const perRow = Math.max(1, Math.floor((W - bay) / sw));
    return { W, bay, sw, sh, perRow };
  }

  // ---- walking --------------------------------------------------------------

  aisle(f, row) { return f.y + WALL_H + row * q(SLOT_H) + q(128); }

  doorSpot(f) { return { x: 18, y: f.y + 52 }; }

  furnitureSpot(f) { return { x: f.bay >= 120 ? f.bay - 104 : 20, y: f.y + 52 }; }

  walkTo(from, to, row, f, speed = WALK) {
    const pts = [], y = this.aisle(f, row);
    if (from) pts.push({ x: from.x, y });
    pts.push({ x: to.x, y }, { x: to.x, y: to.y });
    let prev = from ?? to;
    for (const p of pts) {
      p.ms = Math.max(16, Math.round(Math.hypot(p.x - prev.x, p.y - prev.y) / speed));
      p.facing = p.y < prev.y ? "back" : "front";
      p.from = { x: prev.x, y: prev.y };
      prev = p;
    }
    return pts;
  }

  tick() {
    if (!this.floors.length) return false;
    const now = Date.now(), slow = this.n++ % 4 === 0;
    let changed = false;
    for (const a of this.people) {
      const seat = this.seats[a.address], f = this.floors.find((x) => x.id === a.floorId), t = this.trips[a.address];
      if (!seat || !f) { if (t) { delete this.trips[a.address]; changed = true; } continue; }
      if (t) {
        if (busy(a) && t.phase === "there") { t.until = 0; }
        if (now < t.until) continue;
        changed = true;
        if (t.i < t.path.length - 1) { t.i++; t.until = now + t.path[t.i].ms; continue; }
        if (t.phase === "going") { Object.assign(t, { phase: "there", until: now + 3000 + Math.random() * 8000 }); continue; }
        if (t.phase === "there") {
          const path = this.walkTo(t.path[t.i], seat, seat.row, f);
          Object.assign(t, { phase: "back", path, i: 0, until: now + path[0].ms });
          continue;
        }
        delete this.trips[a.address];
      } else if (slow && !busy(a) && a.stage === "fed" && a.seatIndex === 0 && Math.random() < (a.status === "done" ? 0.004 : 0.01) * (props()?.demo ? 3 : 1)) {
        const path = this.walkTo(seat, this.furnitureSpot(f), seat.row, f);
        this.trips[a.address] = { phase: "going", path, i: 0, until: now + path[0].ms };
        changed = true;
      }
    }
    for (const k of Object.keys(this.bubbles)) if (now >= this.bubbles[k].until) { delete this.bubbles[k]; changed = true; }
    return this.moveCat(now) || changed;
  }

  // Beats between redraws.
  pace() {
    const moving = this.people.some((a) => busy(a) || (this.trips[a.address] && this.trips[a.address].phase !== "there"));
    return moving || Date.now() < (this.cat.t0 ?? 0) + this.cat.ms ? 2 : 4;
  }

  along(p, until) {
    if (!p.from) return p;
    const u = Math.max(0, Math.min(1, 1 - (until - this.t) / p.ms));
    return { x: Math.round(p.from.x + (p.x - p.from.x) * u), y: Math.round(p.from.y + (p.y - p.from.y) * u) };
  }

  catX() {
    const c = this.cat, u = Math.min(1, (this.t - (c.t0 ?? 0)) / c.ms), from = c.from ?? c.x;
    return Math.round(from + (c.x - from) * u);
  }

  moveCat(now) {
    const c = this.cat;
    if (now < c.until || !this.floors.length) return false;
    const R = Math.random();
    if (R < 0.1) c.floor = Math.floor(Math.random() * this.floors.length);
    const to = 20 + Math.random() * Math.max(100, (this.W ?? 400) - 60);
    c.ms = Math.round(Math.abs(to - c.x) / CAT_WALK);
    c.left = to < c.x;
    c.from = c.x;
    c.t0 = now;
    c.x = Math.round(to);
    c.until = now + c.ms + (Math.random() < 0.4 ? 8000 + Math.random() * 15000 : 1000 + Math.random() * 3000);
    return true;
  }

  // ---- input ----------------------------------------------------------------

  clamp() {
    if (!this.sized) return;
    const maxY = Math.max(0, (this.H ?? 0) - this.size.height), maxX = Math.max(0, (this.worldW ?? 0) - (this.W ?? 0));
    this.sy = Math.min(maxY, Math.max(0, this.sy));
    this.px = Math.min(maxX, Math.max(0, this.px));
  }

  wheel(e, cx) {
    const dx = e.delta?.x ?? 0, dy = e.delta?.y ?? 0;
    const sideways = e.modifiers?.shift || Math.abs(dx) > Math.abs(dy) || this.px > (this.W ?? 0) / 2;
    if (sideways) this.px -= (Math.abs(dx) > Math.abs(dy) ? dx : dy);
    else this.sy -= dy;
    this.clamp();
    cx.notify();
  }

  main(args) {
    if (props()?.demo) return;
    const home = props()?.mainHome;
    if (!home) return run(args[0], Object.fromEntries(args.slice(1).reduce((acc, v, i, all) => (i % 2 ? acc : [...acc, [all[i].replace(/^--/, ""), all[i + 1]]]), [])));
    exec("env", [`HERDR_APP_HOME=${home}`, "herdr-app", "do", ...args]).catch((e) => console.log(`building: ${e}`));
  }

  focus(a) { this.main(["agent.focus", "--terminal", a.address]); }

  hire(spaceId, cx) {
    cx.spawn(async () => {
      const ag = (await knownAgents()).find((x) => x.installed);
      this.main(["tab.new", "--space", spaceId, ...(ag ? ["--argv", JSON.stringify(ag.run)] : [])]);
    });
  }

  // ---- drawing --------------------------------------------------------------

  screen(a, cq) {
    const s = r(cq(6), cq(5), cq(54), cq(34), a ? SCREEN[a.status] ?? SCREEN.idle : "#1c2028");
    if (!a) return s;
    if (a.status === "working")
      return s.children([0, 1, 2, 3].map((i) => r(cq(5), cq(5 + i * 7), swing(this.t, 600 + ((i * 337) % 700) + (a.address.length * 53) % 300, cq(6), cq(40 - i * 6)), Math.max(1, cq(3)), "#7ee0a0")));
    if (a.status === "blocked") {
      const fs = Math.max(8, cq(12));
      const col = this.beat % 4 < 2 ? "#fff8e1" : "#fff8e140";
      return s.flex().items_center().justify_center().child(v_flex().items_center().children([txt("NEEDS", fs, col), txt("YOU", fs, col)]));
    }
    if (a.status === "done") return s.flex().items_center().justify_center().child(txt("OK", Math.max(8, cq(16)), "#bfe0ff"));
    const R = rng(hash(a.address)), lw = Math.max(14, cq(24)), lh = Math.max(8, cq(12)), fs = Math.max(8, cq(10));
    const xp = 3600 + Math.floor(R() * 2400), yp = 2200 + Math.floor(R() * 1600);
    return s.child(div().absolute().left(swing(this.t, xp, 0, cq(54) - lw)).top(swing(this.t, yp, 0, cq(34) - lh)).w(lw).h(lh).bg(pick(R, DVD)).flex().items_center().justify_center()
      .child(txt("DVD", fs, "#36404c")));
  }

  desk(c) {
    const { tab, x, y, i } = c, a = c.lead, R2 = (x, y, w, h, col) => r(q(x), q(y), q(w), q(h), col), dl = deskLook(i, this.seed), status = a?.status;
    const stage = a?.stage ?? "fed", webbed = stage === "cobweb" || stage === "skeleton";
    const el = div().absolute().left(x).top(y).w(q(SLOT_W)).h(q(130))
      .child(R2(52, 0, 66, 44, "#2b2f3a").child(this.screen(a, q)).when(webbed, (e) => e.children(cobweb(R2, 66))))
      .child(R2(80, 44, 10, 6, "#2b2f3a")).child(R2(70, 50, 30, 3, "#2b2f3a"))
      .child(R2(24, 52, 122, 12, "#f0dcb0")).child(R2(24, 64, 122, 20, "#d4b27c")).child(R2(24, 64, 122, 3, "#b48a52"))
      .child(R2(28, 84, 8, 18, "#b48a52")).child(R2(134, 84, 8, 18, "#b48a52"))
      .child(R2(66, 54, 38, 6, "#e7e9ee"))
      .children(a ? ramen(R2, status === "working", this.beat, K) : [R2(110, 44, 9, 10, dl.mug)])
      .children(a ? pile(R2, a.turns) : [])
      .child(R2(30, 50, 14, 3, "#3a3a3a")).child(R2(35, 32, 3, 18, "#3a3a3a")).child(R2(28, 26, 18, 8, dl.lamp))
      .when(a && (a.focused || this.night), (e) => e.child(R2(26, 34, 22, 18, "#ffe9a055")).child(R2(31, 34, 12, 3, "#fff3b0")))
      .children(a?.where === "api" ? meter(R2, status === "working", this.beat, K) : [])
      .children(clutter(dl.clutter, R2))
      .children(tower(R2, a?.where, status, this.beat))
      .when(tab.retired, (e) => e.children(vacated(R2)));
    if (!a) el.child(R2(70, 78, 30, 26, "#3d4454")).child(R2(83, 104, 4, 8, "#2b2f3a")).child(R2(72, 112, 26, 4, "#2b2f3a"));
    else if (webbed) el.children(chairWeb(R2));
    return el.id(`desk-${tab.id}`).cursor_pointer()
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click(() => a ? this.focus(a) : tab.terminal && this.main(["pane.focus", "--terminal", tab.terminal]))
      .on_hover((on, cx) => {
        const next = on ? tab.id : this.hover === tab.id ? null : this.hover;
        if (next !== this.hover) { this.hover = next; cx.notify(); }
      });
  }

  label(c) {
    const { tab, x, y } = c, a = c.lead, fs = Math.max(8, q(12));
    const line2 = a?.visitor ? "VISITOR" : a?.model ? `${modelName(a.model)}${a.effort ? ` ${a.effort}` : ""}` : "";
    return v_flex().absolute().left(x).top(y + q(130)).w(q(SLOT_W)).items_center()
      .child(h_flex().justify_center().gap(q(6)).items_center()
        .when(!!a, (e) => e.child(icon(a.program, q(14))))
        .child(txt((tab.retired ? "cleared out" : a?.title && a.title !== "Claude Code" ? a.title : tab.name).slice(0, 18), fs, a?.focused ? "#fff8e1" : ink)))
      .when(!!line2, (e) => e.child(txt(line2.slice(0, 22), Math.max(8, q(11)), a?.visitor ? "#a8322a" : "#5c3a22")))
      .when((c.more ?? 0) > 0, (e) => e.child(txt(`+${c.more} more`, Math.max(8, q(11)), "#a8322a")));
  }

  person(a, c, index) {
    const t = this.trips[a.address], id = `w-${a.address}`, skeleton = a.stage === "skeleton", kind = rank(a.model), s = S;
    const lk = dress(look(a), a.model, skeleton), seat = this.seats[a.address];
    let pos = seat, body;
    // A skeleton stays in the chair, and nobody stands at the desk unless they are working.
    let pose = POSE[a.effort] ?? { pose: "sit", beats: 4 };
    if (skeleton || (pose.pose === "stand" && a.status !== "working")) pose = { pose: "sit", beats: pose.beats };
    const hop = (el, beats, up) => el.top(Math.floor(this.beat / beats) % 2 ? -up : 0);
    if (t) {
      const p = t.path[t.i], there = t.phase === "there";
      pos = there ? p : this.along(p, t.until);
      body = there ? standing(lk, s, "back", false, a.furniture === "cooler" ? "cup" : a.furniture === "shelf" ? "book" : null, id) : hop(walker(lk, s, p.facing, id, kind), 2, s);
    } else if (index > 0) {
      body = stander(lk, s, id, { kind, skeleton }).id(`${id}-b`);
      if (a.status === "working") hop(body, pose.beats, 1);
      if (a.status === "blocked") hop(body, 2, 4 * s);
    } else if (a.status === "blocked") {
      body = hop(sitter(lk, s, { kind, skeleton }).id(`${id}-sit`), 2, 4 * s);
    } else if (a.status === "done") {
      body = sitter(lk, s, { kind, skeleton, sleeping: true }).id(`${id}-sit`);
    } else if (pose.pose === "loaf") {
      body = loafer(lk, s, { kind, skeleton }).id(`${id}-loaf`);
      if (a.status === "working") hop(body, pose.beats, 1);
    } else if (pose.pose === "stand") {
      pos = { x: seat.x, y: seat.y - q(20) };
      body = stander(lk, s, id, { kind, skeleton, sweat: pose.sweat && a.status === "working", beat: this.beat }).id(`${id}-up`);
      if (a.status === "working") hop(body, pose.beats, Math.max(1, Math.round(s)));
    } else {
      body = sitter(lk, s, { kind, skeleton, slump: pose.slump || a.stage === "hungry" }).id(`${id}-sit`);
      if (a.status === "working") hop(body, pose.beats, Math.max(1, Math.round(s * 0.7)));
    }
    const b = this.bubbles[a.address], asking = !t && a.status === "blocked";
    return div().id(id).absolute().left(pos.x).top(pos.y).w(16 * s).h(20 * s)
      .cursor_pointer().on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click(() => this.focus(a))
      .child(body)
      .when(!t && a.status === "done", (e) => e.child(txt(ZS[Math.floor(this.beat / 4) % 4], 16, "#24406e").absolute().left(14 * s).top(-2 * s)))
      .when(asking, (e) => e.child(bubble(txt("?", 12, ink)).left(11 * s).top(-8 * s)))
      .when(!!b && !asking, (e) => e.child(bubble(v_flex().children(wrapReport(b.text).map((line) => txt(line, 9, ink)))).left(10 * s).top(-8 * s)));
  }

  intern(t, c, n) {
    const x = c.x + q(126) - n * q(14), y = c.y + q(58) + n * q(12), id = `i-${t.address}`, s = INTERN_S;
    const lk = dress(look(t), t.model, false);
    const col = SCREEN[t.status] ?? SCREEN.idle;
    return div().id(id).absolute().left(x).top(y).w(q(44)).h(q(60)).cursor_pointer()
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click(() => this.main(["terminal.peek", "--terminal", t.address]))
      .child(bench(K).left(q(6)).top(q(36)))
      .child(sitter(lk, s, {}).absolute().left(0).top(0).id(`${id}-sit`))
      .child(laptop(col, K).left(q(26)).top(q(16)));
  }

  lights(floors, H, h) {
    const scale = H > 0 ? (h - 40) / H : 1, floor = (f) => Math.max(14, Math.round(f.h * scale));
    let y = Math.round(ROOF * scale);
    const items = floors.map((f) => {
      const top = y, hh = floor(f), st = f.status;
      y += hh;
      const lamp = st === "blocked" ? "#e0483c" : st === "done" ? "#5ab0e0" : st === "working" ? "#5ee08a" : "#3a3f4a";
      const size = st === "working" ? 8 : Math.min(20, hh - 4), mid = top + Math.round(hh / 2 - size / 2);
      const el = div().id(`light-${f.id}`).absolute().left(0).top(top).w(LIGHTS).h(hh - 1).bg(st === "blocked" ? "#a8322a55" : "#2b2f3a").cursor_pointer()
        .on_click((_e, cx) => { this.px = 0; this.sy = f.y; this.clamp(); cx.notify(); })
        .child(r(Math.round(LIGHTS / 2 - size / 2), mid - top, size, size, lamp));
      if (st === "blocked") el.children([]);
      return { el, st, f, mid, size };
    });
    const viewTop = Math.round(this.sy * scale), viewH = Math.round(h * scale);
    const count = (this.dead ?? []).length;
    return div().absolute().right(0).top(0).w(LIGHTS).h(h).bg("#1c2028").id("lights")
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .children(items.map((i) => i.el))
      .children(this.beat % 4 < 2 ? items.filter((i) => i.st === "blocked").map((i) => r(Math.round(LIGHTS / 2 - i.size / 2), i.mid, i.size, i.size, "#ffb0a8")) : [])
      .child(r(0, viewTop, LIGHTS, 2, "#e2a465")).child(r(0, viewTop + viewH - 2, LIGHTS, 2, "#e2a465"))
      .child(div().id("to-yard").absolute().left(0).top(h - 40).w(LIGHTS).h(40).bg(this.px > 0 ? "#3f5234" : "#2f3f27").flex().flex_col().items_center().justify_center().cursor_pointer()
        .on_click((_e, cx) => { this.px = this.px > 0 ? 0 : (this.W ?? 0) + FENCE; this.clamp(); cx.notify(); })
        .child(txt(this.px > 0 ? "<" : "RIP", 10, "#d8d8d8")).child(txt(`${count}`, 10, "#9a9aa6")));
  }

  render() {
    const p = props() ?? {};
    this.t = Date.now();
    if (p.mainHome !== undefined) this.mainHome = p.mainHome;
    const { width: w, height: h } = this.size, world = this.world(), now = world.now;
    const { W, bay, sw, sh, perRow } = this.place(w, h);
    const hour = new Date(now).getHours();
    this.night = hour >= 19 || hour < 6;

    // Floors top to bottom, in space order.
    let y = ROOF, prevRug = -1;
    const computers = [], people = [], interns = [];
    const floors = world.floors.map((f, fi) => {
      let rug = hash(f.id) % RUGS.length;
      if (rug === prevRug) rug = (rug + 1) % RUGS.length;
      prevRug = rug;
      const rows = Math.max(1, Math.ceil(f.tabs.length / perRow));
      const fl = { id: f.id, name: f.name, y, h: WALL_H + rows * sh + SLAB, rug, bay, rows, furniture: FURNITURE[hash(f.id) % FURNITURE.length], status: null, index: fi };
      f.tabs.forEach((tab, ti) => {
        const row = Math.floor(ti / perRow), cx = bay + (ti % perRow) * sw, cy = y + WALL_H + row * sh;
        const team = tab.people.map((a) => ({ ...a, ...hunger(a.fed ?? a.fed_ms, now, a.status), floorId: f.id, furniture: fl.furniture }));
        const shown = team.slice(0, 3), bench = (tab.interns ?? []).slice(0, Math.max(0, 4 - shown.length));
        const more = team.length + (tab.interns ?? []).length - shown.length - bench.length;
        const lead = shown.length ? shown.reduce((best, a) => (URGENT[a.status] ?? 0) > (URGENT[best.status] ?? 0) ? a : best, shown[0]) : null;
        const c = { tab, x: cx, y: cy, i: computers.length, lead: lead && { ...lead, stage: shown[0].stage }, more };
        computers.push(c);
        shown.forEach((a, n) => {
          this.seats[a.address] = n === 0 ? { x: cx + q(61), y: cy + q(50), row } : { x: cx + q(n === 1 ? 22 : 100), y: cy + q(66), row };
          people.push({ a: { ...a, seatIndex: n }, c, n });
          if (!fl.status || (URGENT[a.status] ?? 0) > (URGENT[fl.status] ?? 0)) fl.status = a.status;
        });
        bench.forEach((t, n) => interns.push({ t, c, n }));
      });
      y += fl.h;
      return fl;
    });
    const H = Math.max(y + GROUND, h);
    this.groundY = y;
    this.floors = floors;
    this.people = people.map((x) => x.a);
    if (!p.demo) setAgentOrder(this.people.map((a) => a.address));

    const perCol = Math.max(1, Math.floor((h - YARD_TOP - 10) / STONE_H));
    const dead = this.dead ?? [];
    this.yardW = FENCE + 24 + Math.max(1, Math.ceil(dead.length / perCol)) * STONE_W + 40;
    this.W = W;
    this.H = H;
    this.worldW = W + this.yardW;
    this.clamp();

    // Arrivals come up in the elevator; nobody arrives on startup.
    const ts = Date.now();
    for (const { a } of people) {
      const seat = this.seats[a.address], f = floors.find((x) => x.id === a.floorId);
      if (this.known && !this.known.has(a.address) && !this.trips[a.address]) {
        const door = this.doorSpot(f), path = [{ ...door, ms: 16, facing: "front" }, ...this.walkTo(door, seat, seat.row, f)];
        this.trips[a.address] = { phase: "back", path, i: 0, until: ts + 700 };
        this.doors[f.id] = ts + 4000;
      }
      if (a.report !== this.reports[a.address]) {
        if (this.reports[a.address] !== undefined && a.report) this.bubbles[a.address] = { text: a.report, until: ts + 6000 };
        this.reports[a.address] = a.report;
      }
    }
    this.known = new Set(this.people.map((a) => a.address));
    for (const k of Object.keys(this.trips)) if (!this.known.has(k)) delete this.trips[k];
    if (p.hover && !this.hoverSet) { this.hover = p.hover; this.hoverSet = true; }
    if (p.bubble && this.people[p.bubble]) this.bubbles[this.people[p.bubble].address] = { text: this.people[p.bubble].report ?? "...", until: ts + 60000 };

    const c = this.cat, cf = floors[Math.min(c.floor, floors.length - 1)];
    const hovered = computers.find((x) => x.tab.id === this.hover);
    const inner = div().id("building-inner").absolute().left(0).top(-this.sy).w(W).h(H)
      .transition("top", { duration: 90, easing: "linear" })
      .child(this.shell)
      .children(floors.map((f) => h_flex().absolute().left(f.bay + 8).top(f.y + 3).gap(8).items_center()
        .child(div().px(6).py(2).bg("#c9a23a").border(2).border_color("#6b3f1f").child(txt(f.name.slice(0, 20), 13, "#2b1a10")))
        .child(div().id(`hire-${f.id}`).px(5).py(2).bg("#fbfbf6").border(1).border_color("#6b3f1f").cursor_pointer()
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .on_click((_e, cx) => !p.demo && this.hire(f.id, cx))
          .child(txt("HIRING +", 10, "#a8322a")))))
      .children(computers.map((x) => this.desk(x)))
      .children(computers.map((x) => this.label(x)))
      .when(!!cf, (e) => e.child(div().id("cat").absolute().left(this.catX()).top(this.aisle(cf, 0) + q(30))
        .child(cat(c.coat, INTERN_S, c.left))))
      .children(interns.map(({ t, c: at, n }) => this.intern(t, at, n)))
      .children(people.map(({ a, c: at, n }) => this.person(a, at, n)))
      .when(this.night, (e) => e.child(r(0, 0, W, H, "#0b123650")))
      .when(hour >= 17 && hour < 19, (e) => e.child(r(0, 0, W, H, "#f2a65a1a")))
      .when(!!hovered, (e) => e.child(this.note(hovered, W, sw, now)));

    return div().id("building-root").relative().size_full().overflow_hidden().bg("#1c2028")
      .on_size_change((size, cx) => { this.size = size; this.sized = true; this.clamp(); this.syncViews(); cx.notify(); })
      .on_scroll_wheel((ev, cx) => this.wheel(ev, cx))
      .on_mouse_down("left", (ev) => { this.drag = { x: ev.position.x, y: ev.position.y, px: this.px, sy: this.sy }; })
      .on_mouse_up("left", () => { this.drag = null; })
      .on_mouse_move((ev, cx) => {
        if (!this.drag) return;
        this.px = this.drag.px - (ev.position.x - this.drag.x);
        this.sy = this.drag.sy - (ev.position.y - this.drag.y);
        this.clamp();
        cx.notify();
      })
      .child(div().id("world").absolute().left(-this.px).top(0).w(this.worldW).h(h)
        .child(div().id("building").absolute().left(0).top(0).w(W).h(h).overflow_hidden().child(inner))
        .child(div().id("yard").absolute().left(W).top(0).w(this.yardW).h(h).overflow_hidden().child(this.yard)))
      .child(this.lights(floors, H, h));
  }

  note(c, W, sw, now) {
    const a = c.lead, x = Math.min(c.x + sw - 10, W - 230);
    const lines = a ? [
      [a.title || c.tab.name, ink], [`${a.space_name ?? ""} / ${c.tab.name}`, "#6b5a4a"],
      [`${modelName(a.model) || "unknown model"}${a.effort ? `, ${a.effort}` : ""}, ${a.where ?? "?"}`, "#6b5a4a"],
      [`${a.status.toUpperCase()}${a.age ? `, last fed ${ago(a.age)} ago` : ""}`, a.status === "blocked" ? "#a8322a" : ink],
      ...(a.report ? [[a.report, "#6b5a4a"]] : []),
    ] : [[c.tab.name, ink], [c.tab.retired ? "cleared out" : "nobody in", "#6b5a4a"]];
    return v_flex().absolute().left(x).top(c.y).w(220).p(8).gap(4).bg("#fff27a").border(2).border_color("#d8c440")
      .children(lines.map(([t, col]) => txt(String(t), 11, col).truncate()));
  }
}

const bubble = (content) => div().absolute().px(4).py(2).bg("#ffffff").border(2).border_color(ink).child(content);

function wrapReport(text) {
  const clean = String(text).replace(/\s+/g, " ").trim();
  if (clean.length <= 24) return [clean];
  return [clean.slice(0, 24), clean.length > 48 ? `${clean.slice(24, 45)}...` : clean.slice(24)];
}
