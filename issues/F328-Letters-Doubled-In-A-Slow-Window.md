# F328 — Letters Doubled In A Slow Window

**Status:** Idea.

**What must be true.** A key pressed once reaches a task's console once, however slowly the window answers, and a window
that answers late does not read as a broken one.

In a walk with the window shown over `ssh -Y` the console answered very late and letters came doubled, in the agent's
real answer too; clicks came late as well. That the forwarded display is the cause is inferred, not measured.

## To be checked

- Whether the same happens on a local display, and whether the window in that walk held the fix of
  [F321](README.md#f321), which sends each key typed once. Should it have held it, that fix does not cover this, which
  matters before it goes upstream.
- Whether the letters are sent twice or only shown twice.
