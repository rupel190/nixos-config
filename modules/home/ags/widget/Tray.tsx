import { For, createBinding, createComputed } from "ags"
import { Gtk } from "ags/gtk4"
import AstalTray from "gi://AstalTray"

// AstalTray also owns the StatusNotifierWatcher, so this is where udiskie, Steam etc. register.
function Item(item: AstalTray.TrayItem) {
  const init = (btn: Gtk.MenuButton) => {
    btn.menuModel = item.menuModel
    btn.insert_action_group("dbusmenu", item.actionGroup)
    // apps swap their menu and actions at runtime; without re-inserting, entries render greyed out
    item.connect("notify::menu-model", () => (btn.menuModel = item.menuModel))
    item.connect("notify::action-group", () => btn.insert_action_group("dbusmenu", item.actionGroup))
    // SNI menus are built lazily; ask the app to refresh just before the popover opens
    btn.connect("notify::active", () => btn.active && item.about_to_show())
  }

  return (
    <menubutton
      class="item"
      focusable={false}
      tooltipMarkup={createBinding(item, "tooltipMarkup")}
      $={init}
    >
      <image gicon={createBinding(item, "gicon")} />
    </menubutton>
  )
}

export default function Tray() {
  const items = createBinding(AstalTray.get_default(), "items")

  // hidden rather than empty, so no gap in the end cluster when nothing is registered
  return (
    <box class="Tray" spacing={2} visible={createComputed(() => items().length > 0)}>
      <For each={items}>{(item: AstalTray.TrayItem) => Item(item)}</For>
    </box>
  )
}
