# F328 — Letters Doubled In A Slow Window

**Status:** Idea.

**What must be true.** A key pressed once reaches a task's console once, however slowly the window answers, and a window
that answers late does not read as a broken one.

In a walk with the window shown over `ssh -Y` the console answered very late and letters came doubled, in the agent's
real answer too; clicks came late as well. That the forwarded display is the cause is inferred, not measured.

## To be checked

- The window in that walk ran `0.5.1~snapshot.252`, the package of `8a208932`, which does not hold the fix of
  [F321](README.md#f321), which sends each key typed once. The doubled letters are then most likely that known fault; no
  build holding the fix has been tried over `ssh -Y`. If letters still come doubled with it, the fix does not cover this.
- Whether the late answers have another cause: the fix does not touch them.
