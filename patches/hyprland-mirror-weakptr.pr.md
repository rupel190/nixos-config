# PR draft — hyprwm/Hyprland (NOT SUBMITTED)

Local draft for the fix carried in `hyprland-mirror-weakptr.patch`.
Nothing here has been posted upstream. See also the `damageMirrorsWith` memory note.

**Do not submit before the soak is done** — see "Is it tested?" at the bottom.
Soak started 2026-08-20; the crash recurs roughly weekly, so hold until ~2026-09-03.

---

**Title:** `renderer: don't deref expired mirror weakptrs in damageMirrorsWith`

**Branch:** `fix/damage-mirrors-expired-weakptr`

---

## Describe your PR

`CMonitor::m_mirrors` is a `std::vector<PHLMONITORREF>` — weak refs — and
`damageMirrorsWith()` dereferences each entry at the top of the loop without locking it.
When a mirrored output goes away on a DRM hotplug the ref expires while the entry is still
in the vector, so the next frame null-derefs and takes the whole session down.

The tail of this same loop already guards with `if (auto m = mirror.lock())`, but that sits
six lines *after* the first dereference, so the crash survives it. This locks once at the
top and skips the mirror if it is gone, which also makes the later lock redundant. Holding
the strong ref for the whole body additionally rules out expiry mid-iteration — something
simply moving the existing check up would not do.

Reproduced 5× over two weeks on 0.55.0. Identical backtrace every time:

```
#4 Render::IHyprRenderer::damageMirrorsWith(CSharedPointer<CMonitor>, CRegion const&)
#5 Render::IHyprRenderer::renderMonitor(CSharedPointer<CMonitor>, bool)
#6 Monitor::CMonitorFrameScheduler::onFrame()
```

always immediately after `udev: new udev change event for card1` → `Scanning connectors`.

**Repro:** two outputs; `hyprctl keyword monitor HDMI-A-1,preferred,auto,1,mirror,DP-1`;
then hotplug `DP-1` (unplug, or power-cycle a DP source such as an AV receiver). SEGV on
the next frame.

One file, no header or ABI change, so plugins are unaffected.

<details>
<summary>Disassembly pinning the fault to the first dereference</summary>

```
c95c63:  call   <Hyprutils::Math::CRegion::CRegion(CRegion const&)>   ; CRegion transformed{pRegion};
c95c68:  movsd  0x60,%xmm0                                            ; <-- damageMirrorsWith+0x338, faults
c95c71:  ud2
```

`movsd 0x60,%xmm0` is the absolute-address form (`f2 0f 10 04 25 ...`) — a `double` load
from literal address `0x60`, i.e. null plus the `m_transformedSize` offset. The trailing
`ud2` is GCC's codegen for a branch it proved was UB, which rules out a wild pointer or a
use-after-free: the compiler knew the pointer was null on this path. The faulting
instruction follows the `CRegion` copy-constructor call directly, so it is the first
dereference of `monitor` in the loop body.

</details>

<details>
<summary>Related PRs and a possible follow-up</summary>

- #15733 (`recheck mirrors on ensure`) and #15351 (`don't destroy bound wl_output resources
  on same-name global replace`) both reduce how often a stale entry appears, but neither
  makes the dereference safe.
- `CMonitor` calls `m_mirrorOf->m_mirrors.erase(std::ranges::find_if(...))` in two places
  with no `!= end()` check, which is UB if the entry is already gone. Left alone here to
  keep this fix minimal.
- The hyprtester case added in #15733 already plugs and unplugs a mirrored monitor;
  extending it to unplug the *mirror source* while frames are in flight would cover this
  path.

</details>

## Is it tested?

- [ ] Yes
- [x] No

<!-- Flip these two once the patched compositor has survived real DP-1 hotplugs with the
     HDMI mirror live. Builds clean against 52b368f and is clang-format clean, but "it
     compiles" is not what this box asks. Soak until ~2026-09-03, then delete this comment
     and this whole "do not submit" framing before opening the PR. -->
