// Sample floors for review and screenshots, used only with props {demo: true}: one of everything.
const HOUR = 3600 * 1000, DAY = 24 * HOUR;

export function demoWorld() {
  const now = Date.now();
  const person = (address, status, title, model, effort, where, fedAgo, extra = {}) => ({
    address, status, title, tab_name: title, space_name: "", app: "claude-code", program: null, model, effort, where,
    fed: now - fedAgo, turns: 12, focused: false, visitor: false, ...extra,
  });
  const tab = (id, name, people, extra = {}) => ({ id, name, space: "x", people, retired: false, interns: [], terminal: null, ...extra });
  const dead = Array.from({ length: 46 }, (_, i) => ({
    id: `dead${i}`, title: i % 7 === 0 ? null : ["RECU-demo", "NIX-hAss", "RIE-offer", "GAME-gta", "PRJ-hand", "herdr-setup"][i % 6] + `-${i}`,
    project: "playground", model: i % 4 ? "claude-opus-5-5" : "qwen3.5:9b", effort: "high", turns: 3 + (i * 37) % 400,
    born_ms: now - (i * 5 + 9) * DAY, last_ms: now - i * 5 * DAY,
    cause: ["Starvation", "Died on the job", "Laid off", "Cut off mid-sentence"][i % 4], words: "configs swapped, tests green, should be fine",
  }));
  return {
    now,
    dead,
    floors: [
      { id: "effort", name: "effort: low to max", tabs: [
        tab("e1", "low", [person("e1", "working", "low", "claude-sonnet-5-5", "low", "subscription", HOUR)]),
        tab("e2", "medium", [person("e2", "working", "medium", "claude-sonnet-5-5", "medium", "subscription", HOUR)]),
        tab("e3", "high", [person("e3", "working", "high", "claude-opus-5-5", "high", "subscription", HOUR)]),
        tab("e4", "xhigh", [person("e4", "working", "xhigh", "claude-opus-5-5", "xhigh", "subscription", HOUR)]),
        tab("e5", "max", [person("e5", "working", "max", "claude-opus-5-5", "max", "subscription", HOUR)]),
        tab("e6", "unknown", [person("e6", "idle", "visitor", null, null, null, HOUR, { visitor: true })]),
      ] },
      { id: "ranks", name: "rank and billing", tabs: [
        tab("r1", "opus", [person("r1", "working", "opus sub", "claude-opus-5-5", "high", "subscription", HOUR)]),
        tab("r2", "sonnet api", [person("r2", "working", "sonnet api", "claude-sonnet-5-5", "high", "api", HOUR)]),
        tab("r3", "haiku", [person("r3", "idle", "haiku", "claude-haiku-5-5", "medium", "subscription", HOUR)]),
        tab("r4", "qwen", [person("r4", "working", "qwen local", "qwen3.5:9b", null, "local", HOUR)]),
        tab("r5", "deepseek", [person("r5", "idle", "deepseek", "deepseek-v4-pro", "high", "api", HOUR)]),
      ] },
      { id: "hunger", name: "hunger", tabs: [
        tab("h1", "eating", [person("h1", "working", "eating", "claude-opus-5-5", "high", "subscription", 0, { turns: 60 })]),
        tab("h2", "fed", [person("h2", "idle", "fed", "claude-opus-5-5", "high", "subscription", HOUR, { turns: 30 })]),
        tab("h3", "hungry", [person("h3", "idle", "hungry", "claude-opus-5-5", "high", "subscription", DAY)]),
        tab("h4", "2 days", [person("h4", "idle", "2 days", "claude-opus-5-5", "high", "subscription", 3 * DAY)]),
        tab("h5", "7 days", [person("h5", "idle", "7 days", "claude-opus-5-5", "high", "subscription", 9 * DAY)]),
        tab("h6", "blocked 8d", [person("h6", "blocked", "blocked", "claude-opus-5-5", "low", "subscription", 9 * DAY)]),
      ] },
      { id: "statuses", name: "statuses and shared desks", tabs: [
        tab("s1", "blocked", [person("s1", "blocked", "blocked", "claude-opus-5-5", "high", "subscription", HOUR, { report: "which branch should I use?" })]),
        tab("s2", "done", [person("s2", "done", "done", "claude-opus-5-5", "high", "subscription", HOUR)]),
        tab("s3", "shared", [person("s3a", "working", "shared", "claude-opus-5-5", "high", "subscription", HOUR), person("s3b", "idle", "b", "claude-sonnet-5-5", "medium", "subscription", HOUR), person("s3c", "working", "c", "claude-haiku-5-5", "low", "subscription", HOUR), person("s3d", "idle", "d", "claude-haiku-5-5", "low", "subscription", HOUR), person("s3e", "idle", "e", "claude-haiku-5-5", "low", "subscription", HOUR)]),
        tab("s4", "interns", [person("s4", "working", "lead", "claude-opus-5-5", "high", "subscription", HOUR)], { interns: [{ address: "s4i", status: "working", model: "claude-haiku-5-5" }, { address: "s4j", status: "blocked", model: "claude-haiku-5-5" }] }),
        tab("s5", "shell", []),
        tab("s6", "RIP-old", [], { retired: true }),
      ] },
      { id: "tall", name: "seven tabs wrap", tabs: Array.from({ length: 7 }, (_, i) => tab(`t${i}`, `tab ${i + 1}`, [person(`t${i}`, "idle", `tab ${i + 1}`, "claude-sonnet-5-5", "medium", "subscription", 2 * HOUR)])) },
      { id: "quiet", name: "no agents", tabs: [tab("q1", "1", [])] },
    ],
  };
}
