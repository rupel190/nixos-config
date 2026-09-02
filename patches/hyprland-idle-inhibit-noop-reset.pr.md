# PR draft — hyprwm/Hyprland (NOT SUBMITTED)

Local draft for the fix carried in `hyprland-idle-inhibit-noop-reset.patch`.
Nothing here has been posted upstream. Separate PR from the `damageMirrorsWith`
one — unrelated subsystem, unrelated bug, no shared code.

**Do not submit before the soak is done** — see "Is it tested?" at the bottom.
Soak started 2026-09-02; the false wakes happened ~6×/day, so hold until ~2026-09-06.

---

**Title:** `idle: don't reset idle notifications when the inhibit state is unchanged`

**Branch:** `fix/idle-noop-inhibit-reset`

---

## Describe your PR

`CIdleNotifyProtocol::setInhibit()` writes `isInhibited` and then calls `update()`
on every notification, unconditionally — including when the value it was handed is
the value it already held. `update(0)` calls `reset()`, which sends `resumed` to the
client, and rearms the full timeout. So a `false` → `false` call silently rewinds the
compositor's idle clock and tells every idle client that the user just came back.

That matters because `recheckIdleInhibitorStatus()` is called on window map
(`Window.cpp:1494`), unmap (`:1687`), both focus paths (`FocusState.cpp:151`, `:220`)
and fullscreen changes (`FullscreenController.cpp:501`). On a session with no idle
inhibitors and no `idleinhibit` window rules — the common case — every one of those
rechecks falls through to `setInhibit(false)`. The result is that **any** window
opening, closing or taking focus resets the idle timer.

Two user-visible consequences, both observed:

1. A background window appearing on an idle, locked, DPMS-off session makes
   idle daemons run their resume hooks, so the monitors light back up on their own
   with the lock screen on them. Steam's notification toasts (unmanaged X11 windows,
   `notificationtoasts_NN_desktop`) are enough — 81 of them over two days here.
2. Worse and invisible: while such windows arrive more often than the idle timeout,
   the idle lock **never fires at all**. A machine configured to lock after 5 minutes
   can sit unlocked indefinitely because a background app is being chatty.

The fix is to make the setter a no-op when nothing changed. A genuine `true` → `false`
transition still calls `update()` and rearms, so releasing a real inhibitor is
unaffected, and repeated `setInhibit(true)` was already idempotent (`update()` under
inhibition just calls `reset()` and returns without arming a timer).

**Repro:** no inhibitors, no `idleinhibit` rules.

```
swayidle -w timeout 10 'echo IDLE' resume 'echo RESUME'
```

Wait for `IDLE`, then open and close any window without touching input or the pointer
(e.g. from a second machine over SSH: `hyprctl dispatch exec kitty`, then close it).
`RESUME` fires, and the timeout restarts. Expected: nothing, since there was no input.

One file, three lines, no header or ABI change, so plugins are unaffected.

<details>
<summary>Evidence from the wild</summary>

Correlating an idle daemon's resume events against the offending app's own log
(`journalctl -o short-precise` vs Steam's `steamui_html.txt`):

- 11 of 11 spontaneous DPMS-on events landed 220–880 ms **after** a Steam
  `PopupHTMLWindow`, never before it.
- Every wake actually caused by input — the ones followed by an unlock seconds later
  — had no popup anywhere near it.

So the window is leading the resume, not reacting to the screens coming back.

</details>

<details>
<summary>Alternatives considered</summary>

- **Guard in `recheckIdleInhibitorStatus()` instead**, tracking the last computed
  state there. Same effect, but `setInhibit` owns `isInhibited`, so the invariant
  "changing nothing does nothing" belongs with the state it protects — and any future
  caller gets it for free.
- **Stop calling the recheck on every focus change.** Larger blast radius: the focus
  hook is genuinely needed for `idleinhibit focus` rules, so removing it would break
  a documented feature to fix an unrelated bug.
- **Reset only notifications that are currently idled.** Would fix the spurious
  `resumed` but not the rearmed timeout, so the auto-lock suppression would survive.

</details>

## Is it tested?

- [ ] Yes
- [x] No

<!-- Builds clean against 52b368f, both patches apply without fuzz, but "it compiles"
     is not what this box asks. Flip these once the patched compositor has gone several
     days with Steam running and the session left idle overnight, with no `Resumed`
     in the idle daemon's log that lacks a matching input event. Then delete this
     comment and the whole "do not submit" framing before opening the PR. -->
