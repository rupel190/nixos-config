import { With } from "ags"
import { groups, type MonitorGroup } from "../service/windows"

// One cluster per monitor, in physical left-to-right order. Workspace numbers are
// deliberately absent — the question this answers is "which screen is Signal on",
// and the workspace is secondary to that.
export default function Windows() {
  return (
    <box class="Windows">
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
  )
}
