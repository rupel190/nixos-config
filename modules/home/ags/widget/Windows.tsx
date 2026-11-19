import { Gtk } from "ags/gtk4"
import { With } from "ags"
import { groups, type MonitorGroup } from "../service/windows"

// One cluster per monitor, in physical left-to-right order. Workspace numbers are
// deliberately absent — the question this answers is "which screen is Signal on",
// and the workspace is secondary to that.
//
// A scrolledwindow rather than a box so this list is what gives way when the bar
// runs out of room. A box's minimum width is its full contents, and on the 1080px
// vertical screen that made the bar wider than the monitor: the layer surface
// overhung the right edge and took the display button with it. EXTERNAL keeps
// the natural width when there is space and clips the tail when there is not.
export default function Windows() {
  return (
    <scrolledwindow
      class="Windows"
      hscrollbarPolicy={Gtk.PolicyType.EXTERNAL}
      vscrollbarPolicy={Gtk.PolicyType.NEVER}
      propagateNaturalWidth
    >
      {/* One fixed child: With swaps what it renders, and a scrolledwindow
          holds a single child rather than appending a list. */}
      <box>
        <With value={groups}>
          {(list: MonitorGroup[]) => (
            <box>
              {list.map((g) => (
                <box class="cluster">
                  {g.entries.map((e) => (
                    <button
                      class={e.visible ? "app visible" : "app"}
                      focusable={false}
                      onClicked={() => e.client.focus()}
                      tooltipText={
                        e.count > 1
                          ? `${e.title} — ${g.name} (${e.count} windows)`
                          : `${e.title} — ${g.name}`
                      }
                    >
                      <image iconName={e.icon} pixelSize={16} />
                    </button>
                  ))}
                </box>
              ))}
            </box>
          )}
        </With>
      </box>
    </scrolledwindow>
  )
}
