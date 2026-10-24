import { createComputed } from "ags"
import { cpu, gpu, ram } from "../service/sysmon"

// Nerd Font codepoints as escapes rather than literal glyphs, so the source
// stays readable in an editor without the font. Coverage verified in MonaspiceXe
// Nerd Font Mono with `fc-list ":charset=f4bc"`.
// nf-oct-cpu was the obvious pick for CPU and the wrong one: at 13px it is a
// small round chip, near-identical to nf-md-memory beside it. The pinned-chip
// silhouette is the one that reads as a processor at this size.
const ICON_CPU = "\u{F061A}" // nf-md-chip
const ICON_RAM = "\u{F035B}" // nf-md-memory
// Chosen by rendering the candidates at the bar's own 14px and looking, for the
// reason the CPU note above gives: md-video_3d just spells "3D", and both
// expansion_card variants were the only shapes that stay horizontal next to two
// squarish neighbours. The variant is mushier at this size.
const ICON_GPU = "\u{F08AE}" // nf-md-expansion_card

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

  const gpuLabel = createComputed(() => {
    const v = gpu()
    return v === null ? PENDING : `${v.pct}%`
  })

  const tooltip = createComputed(() => {
    const c = cpu()
    const r = ram()
    if (c === null || r === null) return "Sampling…"
    const g = gpu()
    // VRAM rides in the tooltip rather than the bar for the same reason the RAM
    // percentage does: one headline number per stat, the other framing a hover
    // away. A third pair of digits would widen the end cluster for little gain.
    const gpuPart =
      g === null
        ? ""
        : `  ·  GPU ${g.pct}%  ·  VRAM ${g.vramUsedGiB.toFixed(1)} / ${g.vramTotalGiB.toFixed(1)} GiB (${g.vramPct}%)`
    return `CPU ${c}%  ·  RAM ${r.usedGiB.toFixed(1)} / ${r.totalGiB.toFixed(1)} GiB (${r.pct}%)${gpuPart}`
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
      {/* Hidden, not em-dashed, where the driver exposes no busy counter — on
          cordyceps this stat simply does not exist rather than never resolving. */}
      <box class="stat" spacing={6} visible={createComputed(() => gpu() !== null)}>
        <label class="icon" label={ICON_GPU} />
        <label class="value" label={gpuLabel} xalign={0} />
      </box>
    </box>
  )
}
