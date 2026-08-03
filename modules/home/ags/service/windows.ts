import AstalHyprland from "gi://AstalHyprland"
import AstalApps from "gi://AstalApps"
import Gdk from "gi://Gdk?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import { createState } from "ags"
import { idle } from "ags/time"

// Which screen is that window hiding on? Groups every open window by the monitor
// it lives on, ordered physically left-to-right, so the cluster's position in the
// bar mirrors where you have to turn your head.
//
// Monitor comes from the client itself rather than being inferred from the
// workspace number. The numbering in workspaces.nix happens to encode it today
// (1-3 DP-1, 4-6 DP-2, 7-9 HDMI-A-2), but that stops being true the moment
// dynamic `workspace, empty` workspaces get adopted.

const hyprland = AstalHyprland.get_default()
const apps = AstalApps.Apps.new()

export type AppEntry = {
  key: string
  icon: string
  title: string
  visible: boolean
  count: number
  client: AstalHyprland.Client
}

export type MonitorGroup = {
  name: string
  x: number
  entries: AppEntry[]
}

const [groups, setGroups] = createState<MonitorGroup[]>([])
export { groups }

// ── Icon resolution ──────────────────────────────────────────────────────────

const FALLBACK_ICON = "application-x-executable"

let iconTheme: Gtk.IconTheme | null = null

// A resolved icon name is not the same thing as a rendering icon: several
// .desktop files reference icons that were never packaged (bambu-studio.desktop
// points at com.bambulab.BambuStudio, which is absent here). Without this check
// those render as a broken-image glyph in the bar.
function themeHasIcon(name: string): boolean {
  if (!iconTheme) {
    const display = Gdk.Display.get_default()
    if (!display) return false
    iconTheme = Gtk.IconTheme.get_for_display(display)
  }
  return iconTheme.has_icon(name)
}

// Window classes and desktop entries disagree constantly — "BambuStudio" against
// bambu-studio.desktop, "org.keepassxc.KeePassXC" against keepassxc.desktop.
// Reducing both to lowercase alphanumerics collapses most of that.
const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, "")

const iconCache = new Map<string, string>()

function iconFor(cls: string): string {
  const cached = iconCache.get(cls)
  if (cached !== undefined) return cached

  const target = norm(cls)
  const tail = norm(cls.split(".").pop() ?? cls)
  const entryOf = (a: AstalApps.Application) => (a.entry ?? "").replace(/\.desktop$/, "")
  const list = apps.get_list()

  const match =
    list.find((a) => norm(a.wm_class ?? "") === target) ??
    list.find((a) => norm(entryOf(a)) === target) ??
    list.find((a) => norm(entryOf(a).split(".").pop() ?? "") === tail) ??
    list.find((a) => norm(a.name ?? "") === target)

  const name = match?.icon_name
  const icon = name && themeHasIcon(name) ? name : FALLBACK_ICON
  iconCache.set(cls, icon)
  return icon
}

// ── Grouping ─────────────────────────────────────────────────────────────────

// `With` rebuilds its children on every emission, and hyprland's `event` signal
// fires for things as mundane as moving the pointer between windows. Emitting
// only when the rendered shape actually differs keeps the icon row from being
// torn down and rebuilt several times a second.
let lastSignature = ""

function recompute() {
  const byMonitor = new Map<number, MonitorGroup>()
  for (const m of hyprland.get_monitors()) {
    byMonitor.set(m.id, { name: m.name, x: m.x, entries: [] })
  }

  for (const c of hyprland.get_clients()) {
    const monitor = c.monitor
    const group = monitor ? byMonitor.get(monitor.id) : undefined
    if (!group || !c.class) continue

    // "Visible" means the window's workspace is the one its monitor is currently
    // showing — which is exactly the difference between a window you can see and
    // one hiding on another workspace of that screen.
    const visible = c.workspace?.id === monitor!.activeWorkspace?.id

    const existing = group.entries.find((e) => e.key === c.class)
    if (existing) {
      existing.count += 1
      existing.visible ||= visible
      // Prefer a visible instance as the click target, so clicking an icon for
      // an app open on two workspaces goes to the one already on screen.
      if (visible) existing.client = c
    } else {
      group.entries.push({
        key: c.class,
        icon: iconFor(c.class),
        title: c.title || c.class,
        visible,
        count: 1,
        client: c,
      })
    }
  }

  const next = Array.from(byMonitor.values())
    .filter((g) => g.entries.length > 0)
    .sort((a, b) => a.x - b.x) // physical left-to-right

  const signature = JSON.stringify(
    next.map((g) => [g.name, g.entries.map((e) => [e.key, e.icon, e.visible, e.count])]),
  )
  if (signature === lastSignature) return
  lastSignature = signature
  setGroups(next)
}

let scheduled = false

export function init() {
  recompute()
  // Coalesced onto an idle tick: a single window move emits several hyprland
  // events back to back, and recomputing once per burst is enough.
  hyprland.connect("event", () => {
    if (scheduled) return
    scheduled = true
    idle(() => {
      scheduled = false
      recompute()
    })
  })
}
