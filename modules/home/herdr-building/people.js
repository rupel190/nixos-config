import { div } from "gpui-kit";
import { r, seated, standing, hash, txt, sprite } from "./art.js";

// What The Building adds to Office's art: rank, effort, hunger, the computer's kind and the dead.
// Office's art.js stays as shipped (MIT, zuccs/herdr-office-layout).

const DAY = 24 * 3600 * 1000;
const BONE = "#e8e4d0", SHADE = "#8d8a78";
const VENDORS = [[/claude|opus|sonnet|haiku|fable/, "#d97757"], [/deepseek/, "#4f7dc9"], [/qwen|qwq/, "#3f9aa6"], [/flint/, "#7a8a3a"], [/gpt|codex/, "#2f3640"], [/gemini/, "#4f7dc9"]];
const darken = (hex, by) => `#${[1, 3, 5].map((i) => Math.round(parseInt(hex.slice(i, i + 2), 16) * by).toString(16).padStart(2, "0")).join("")}`;

// Hand-written on purpose: no API says how good a model is.
export function rank(model) {
  const m = (model ?? "").toLowerCase();
  if (!m) return "unknown";
  if (/opus|fable/.test(m)) return "suit";
  if (/sonnet|deepseek/.test(m)) return "shirt";
  if (/haiku/.test(m)) return "tee";
  return "hoodie";
}

export function modelName(model) {
  if (!model) return "";
  const c = /^claude-([a-z]+)-(\d+)(?:-(\d+))?/.exec(model);
  if (!c) return model.replace(/^.*\//, "").slice(0, 14);
  return `${c[1][0].toUpperCase()}${c[1].slice(1)} ${c[2]}${c[3] ? `.${c[3]}` : ""}`;
}

export function hunger(fed, now, status) {
  if (status === "working" || status === "blocked" || !fed) return { stage: "fed", age: 0 };
  const age = now - fed;
  return { age, stage: age >= 7 * DAY ? "skeleton" : age >= 2 * DAY ? "cobweb" : age >= DAY / 2 ? "hungry" : "fed" };
}

export function ago(ms) {
  const h = ms / 3600000;
  return h < 1 ? `${Math.round(h * 60)} min` : h < 48 ? `${Math.round(h)} hours` : `${Math.round(h / 24)} days`;
}

export function dress(lk, model, skeleton) {
  const vendor = VENDORS.find(([re]) => re.test((model ?? "").toLowerCase()))?.[1];
  const kind = rank(model), base = vendor ?? lk.shirt;
  if (skeleton) return { ...lk, hair: BONE, skin: BONE, style: "bald", glasses: false, shirt: SHADE };
  return { ...lk, shirt: kind === "suit" ? darken(base, 0.42) : base };
}

// The back of the outfit, drawn over the chair so rank and vendor read from behind.
function neck(kind, base, s) {
  if (kind === "unknown") return [];
  const out = [r(4 * s, 9 * s, 8 * s, 6 * s, base)];
  if (kind === "suit") out.push(r(5 * s, 8 * s, 6 * s, s, "#f4f4f0"), r(8 * s, 11 * s, s, 4 * s, "#151515"));
  if (kind === "shirt") out.push(r(5 * s, 8 * s, 6 * s, s, "#f4f4f0"));
  if (kind === "tee") out.push(r(2 * s, 9 * s, 2 * s, 4 * s, "#e0ac84"), r(12 * s, 9 * s, 2 * s, 4 * s, "#e0ac84"));
  if (kind === "hoodie") out.push(r(4 * s, 6 * s, 8 * s, 3 * s, base), r(6 * s, 11 * s, 4 * s, 3 * s, "#00000030"));
  return out;
}

// In the chair, from behind.
export function sitter(lk, s, opts) {
  const { kind = "unknown", skeleton, sleeping, slump } = opts;
  const body = div().relative().w(16 * s).h(20 * s)
    .child(seated(lk, s, sleeping || slump).absolute().left(0).top(0))
    .children(skeleton ? ribs(s) : neck(kind, lk.shirt, s));
  return body;
}

const ribs = (s) => [
  r(7 * s, 9 * s, 2 * s, 9 * s, BONE),
  ...[10, 12, 14].map((y) => r(4 * s, y * s, 8 * s, s, BONE)),
];

// Effort low: leaning back, the legs past both ears and the feet up on the desk.
export function loafer(lk, s, opts) {
  const { kind = "unknown", skeleton } = opts;
  const leg = skeleton ? BONE : "#2b2f3a", shoe = skeleton ? BONE : "#151515";
  return div().relative().w(16 * s).h(24 * s)
    .child(seated(lk, s, false).absolute().left(0).top(2 * s))
    .child(r(0, -s, 3 * s, 11 * s, leg)).child(r(13 * s, -s, 3 * s, 11 * s, leg))
    .child(r(-s, -3 * s, 4 * s, 3 * s, shoe)).child(r(13 * s, -3 * s, 4 * s, 3 * s, shoe))
    .child(div().absolute().left(0).top(2 * s).children(skeleton ? ribs(s) : neck(kind, lk.shirt, s)));
}

// Effort xhigh and max: on their feet at the desk.
export function stander(lk, s, id, opts) {
  const { kind = "unknown", skeleton, sweat } = opts;
  const el = div().relative().w(16 * s).h(17 * s).child(standing(lk, s, "back", false, null, id));
  if (kind === "suit" || kind === "shirt") el.child(r(5 * s, 7 * s, 6 * s, s, "#f4f4f0"));
  if (skeleton) el.child(r(7 * s, 8 * s, 2 * s, 6 * s, BONE));
  if (sweat) el.child(r(14 * s, s, s, 2 * s, "#7fb8e8").id(`${id}-sweat`).loop("top", { from: s, to: 6 * s, period: 500, easing: "linear" }));
  return el;
}

export function walker(lk, s, facing, id, kind) {
  const el = div().relative().w(16 * s).h(17 * s).child(standing(lk, s, facing, true, null, id));
  if (facing === "front" && (kind === "suit" || kind === "shirt")) el.child(r(7 * s, 7 * s, 2 * s, 4 * s, kind === "suit" ? "#a8322a" : "#2f5a7a"));
  return el;
}

export function bench(k) {
  const q = (v) => Math.round(v * k);
  return div().absolute().w(q(26)).h(q(22)).child(r(q(2), q(10), q(22), q(4), "#6b3f1f")).child(r(q(4), q(14), q(3), q(8), "#6b3f1f")).child(r(q(19), q(14), q(3), q(8), "#6b3f1f"));
}

export function laptop(color, k) {
  const q = (v) => Math.round(v * k);
  return r(0, 0, q(26), q(20), "#2b2f3a").child(r(q(2), q(2), q(22), q(13), color)).child(r(-q(2), q(18), q(30), q(3), "#9a9aa6"));
}

// ---- things on the desk ---------------------------------------------------

export function ramen(R2, steaming, id, k) {
  const cup = [R2(110, 41, 11, 13, "#f4f4f0"), R2(110, 45, 11, 3, "#c94a3a"), R2(109, 40, 13, 2, "#d8dce4")];
  if (steaming) cup.push(txt("~", Math.max(8, Math.round(12 * k)), "#ffffffcc").absolute().left(Math.round(110 * k)).top(Math.round(27 * k)).id(id).frames(["", "~", "≈", "~"], 380));
  return cup;
}

// A pile of finished cups beside the desk: one per ten real prompts, at most six.
export function pile(R2, turns) {
  const n = Math.min(6, Math.ceil((turns ?? 0) / 10));
  return Array.from({ length: n }, (_, i) => [R2(5, 92 - i * 6, 13, 6, "#f4f4f0"), R2(5, 94 - i * 6, 13, 2, "#c94a3a")]).flat();
}

export function tower(R2, where, status, id) {
  if (where === "local") {
    return [
      R2(148, 34, 20, 66, "#d9d2b8").child(R2(3, 6, 14, 3, "#8a8570")).child(R2(3, 12, 14, 3, "#8a8570")),
      R2(152, 58, 4, 4, "#e0483c").id(`${id}-a`).loop("opacity", { from: 0.2, to: 1, period: 340 }),
      R2(160, 58, 4, 4, "#5ee08a").id(`${id}-b`).loop("opacity", { from: 1, to: 0.2, period: 520 }),
      R2(151, 74, 14, 14, "#6a6658"),
    ];
  }
  const dark = where === "api";
  return [R2(150, 58, 16, 40, dark ? "#3a3f4a" : "#d9dce3").child(R2(3, 6, 8, 2, "#555")).child(R2(5, 26, 4, 4, status === "working" ? "#5ee08a" : "#777"))];
}

// Billed by the token: a meter that runs while it works.
export function meter(R2, working, id, k) {
  const fs = Math.max(8, Math.round(11 * k));
  const face = R2(26, 32, 20, 18, "#2b2f3a").child(txt("$", fs, "#f0c860").absolute().left(Math.round(5 * k)).top(Math.round(2 * k)).id(id).when(working, (e) => e.frames(["$", " ", "$", "¢"], 300)));
  return [face, R2(28, 26, 16, 4, "#f0c860"), R2(30, 22, 12, 4, "#d8a840")];
}

export function cobweb(R2, w) {
  const web = "#ffffffc8", out = [];
  for (let i = 0; i < 5; i++) {
    const len = 18 - i * 4;
    out.push(R2(0, i * 4, len, 1.2, web), R2(w - len, i * 4, len, 1.2, web));
  }
  out.push(R2(0, 0, 1.2, 18, web), R2(8, 0, 1.2, 10, web), R2(w - 1.2, 0, 1.2, 18, web), R2(w - 9, 0, 1.2, 10, web));
  return out;
}

export function chairWeb(R2) {
  return [R2(70, 78, 30, 2, "#ffffff80"), R2(72, 84, 14, 2, "#ffffff60"), R2(84, 90, 16, 2, "#ffffff60"), R2(80, 78, 2, 26, "#ffffff40")];
}

export function vacated(R2) {
  return [R2(62, 36, 46, 22, "#b48a52"), R2(62, 36, 46, 5, "#8a6a3a"), R2(80, 44, 10, 4, "#6b4a28")];
}

// ---- the graveyard --------------------------------------------------------

const STONE = [
  "...GGGGGGGG...",
  "..GGGGGGGGGG..",
  ".GGGGGGGGGGGG.",
  "GGGGGGGGGGGGGG",
];

export function headstone(d, now) {
  const R = hash(d.id), dark = R % 3 === 0, stone = dark ? "#74767c" : "#8d8f94";
  const old = now - (d.last_ms ?? now), moss = Math.min(6, Math.floor(old / (14 * DAY)));
  const name = d.title?.replace(/^rip-/i, "") ?? d.project;
  const el = div().absolute().w(80).h(88)
    .child(sprite(STONE, { G: stone }, 5.5).absolute().left(1).top(0))
    .child(r(1, 22, 77, 56, stone))
    .child(div().absolute().left(0).top(9).w(80).flex().justify_center().child(txt("R.I.P.", 10, "#2b2b30")))
    .child(div().absolute().left(3).top(26).w(74).flex().justify_center().child(txt(name.slice(0, 13), 9, "#1c1c20")))
    .child(div().absolute().left(3).top(40).w(74).flex().justify_center().child(txt(`${d.turns} turns`, 9, "#33333a")))
    .child(div().absolute().left(3).top(54).w(74).flex().justify_center().child(txt(new Date(d.last_ms ?? now).toISOString().slice(2, 10), 9, "#33333a")))
    .child(r(-3, 76, 86, 8, "#3d2f20"))
    .children(Array.from({ length: moss }, (_, i) => r(2 + ((R >>> i) % 66), 68 + (i % 2) * 5, 10, 4, "#5a7a3a")));
  if (d.cause === "Died on the job") el.child(r(62, 2, 4, 14, "#2b2b30")).child(r(58, 6, 12, 4, "#2b2b30"));
  return el;
}

export const fence = (h, x) => [
  r(x + 8, 96, 6, h - 96, "#2b2b30"),
  ...Array.from({ length: Math.ceil((h - 96) / 34) }, (_, i) => r(x, 100 + i * 34, 22, 4, "#2b2b30")),
];

export const yardGate = (n) => div().absolute().left(40).top(14).p(8).bg("#1c1c20").border(3).border_color("#5a5a66")
  .child(txt("BELOVED CONTEXTS", 14, "#d8d8d8")).child(txt(`${n} in the ground`, 11, "#9a9aa6"));

