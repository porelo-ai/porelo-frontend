# F101 — What The Build Of A Push Did

**Status:** Review; to be walked.

**What must be true.** A person sees on a work tile, and in the work's detail, what the build of the
work's last push did - its verdict, every job and which of them left a log in the task - as the
machine reads it from the forge, and why when it cannot.

## Why

`porelo` follows each commit an `online` task pushes at the forge and hands the verdict and the
logs into the task as Porelo's own files. The contract, as `org.fuin.porelo.Tasks1` says it:

    # The forge whose builds of this task's pushes are followed, as the project names it under builds.forge
    # ("github"); "" when the project names none, or the task is not online. With builds empty and buildProblem
    # empty, it means no push yet.
    buildReader: string,
    # Why the named reader does not follow them: not installed, would not start, speaks another version of the
    # build protocol. "" while it follows them, and when buildReader is "".
    buildProblem: string

`Build` carries `commit`, `verdict`, `jobs`, `since` and `detail`; `jobs` lists every job the forge
reports once the verdict is `failure` or final, each with `name`, `result` and the name of its log
in `/porelo/files`, empty where none was delivered.

## Acceptance

- No reader, or a machine older than builds, says nothing about builds - never *no builds*. Seen to
  fail: a scenario against either answer that finds a *Builds* field.
- A reader with nothing pushed yet says *no push yet*; a build underway says *no jobs yet*. Seen to
  fail: a scenario per state that finds the other words.
- A failed build lists every job with its result and, where one reached the task, its log's file.
  Seen to fail: a scenario whose failed job's log is not named.
- `unknown` says why, a reader that does not work says why, and a verdict or result this interface
  does not know is shown as it comes. Seen to fail: one scenario each.
- Measured end to end on the local VM against a daemon handed over from `porelo`, with its stub
  reader: `Watch` carries each verdict of a push to the tile, and the jobs once it failed.
