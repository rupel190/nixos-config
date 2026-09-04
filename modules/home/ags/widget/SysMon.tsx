import { createComputed } from "ags"
import { cpu, ram } from "../service/sysmon"

// Nerd Font codepoints as escapes rather than literal glyphs, so the source
// stays readable in an editor without the font. Coverage verified in MonaspiceXe
// Nerd Font Mono with `fc-list ":charset=f4bc"`.
// nf-oct-cpu was the obvious pick for CPU and the wrong one: at 13px it is a
// small round chip, near-identical to nf-md-memory beside it. The pinned-chip
// silhouette is the one that reads as a processor at this size.
const ICON_CPU = "\u{F061A}" // nf-md-chip
const ICON_RAM = "\u{F035B}" // nf-md-memory

const PENDING = "—"

export default function SysMon() {
  const cpuLabel = createComputed(() => {
    const v = cpu()
    return v === null ? PENDING : `${v}%`
  })

  // Absolute GiB rather than a percentage, because the question this answers is
  // "is there room for another Proton game" — 17.8 of 62 says that where 29%
  // does not. The percentage is in the tooltip for when it is the useful framing.
  const ramLabel = createComputed(() => {
    const v = ram()
    return v === null ? PENDING : `${v.usedGiB.toFixed(1)}G`
  })

  const tooltip = createComputed(() => {
    const c = cpu()
    const r = ram()
    if (c === null || r === null) return "Sampling…"
    return `CPU ${c}%  ·  RAM ${r.usedGiB.toFixed(1)} / ${r.totalGiB.toFixed(1)} GiB (${r.pct}%)`
  })

  // xalign 0 pins each number's first character against its icon, so the gap
  // stays fixed as the string grows; see the min-width note in style.scss.
  return (
    <box class="SysMon" spacing={12} tooltipText={tooltip}>
      <box class="stat" spacing={6}>
        <label class="icon" label={ICON_CPU} />
        <label class="value" label={cpuLabel} xalign={0} />
      </box>
      <box class="stat" spacing={6}>
        <label class="icon" label={ICON_RAM} />
        <label class="value" label={ramLabel} xalign={0} />
      </box>
    </box>
  )
}
