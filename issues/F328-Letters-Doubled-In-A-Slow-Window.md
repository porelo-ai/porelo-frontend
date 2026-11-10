# F328 — Letters Doubled In A Slow Window

```json
{
  "$schema": "issue-1.json",
  "id": "F328",
  "title": "Letters Doubled In A Slow Window",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 10,
  "blockedBy": [],
  "covers": "A key pressed once reaching a console once, however slowly the window answers."
}
```

**What must be true.** A key pressed once reaches a task's console once, however slowly the window answers, and a window
that answers late does not read as a broken one.

In a walk with the window shown over `ssh -Y` the console answered very late and letters came doubled, in the agent's
real answer too; clicks came late as well. That the forwarded display is the cause is inferred, not measured.

## Measured

The fix of [F321](README.md#f321) holds under a slow display, as far as this measures. A small app holding only `TerminalView` ran on a hidden display, reached through a proxy that delays the X connection by 100 and by 250 milliseconds each way, and keys were typed by XTEST at about 25 a second. What reached `onOutput`:

| | 100 ms | 250 ms |
|---|---|---|
| `xterm` 4.0.0 as published | `aababcabcd…` | `aababcabcd…` |
| `packages/xterm` as patched | each key once | each key once |

So the published package doubles letters under delay, as the walk saw, and the patched one does not.

## To be checked

- The operator watches at the next test. This was not `ssh -Y`, not the whole interface, and not a real network: a proxy adds delay and neither limits bandwidth nor drops anything, and no agent answered.
- Whether the late answers have another cause: the fix does not touch them, and this did not measure them.
