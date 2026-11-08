# F440 — Agents, The Gate's Review And Builds As Designed

**Status:** Review.

**What must be true.** *Agents & providers* reads as one aligned list of agents with their facts, the gate's review
names who wrote and committed a push and its trailer, and a task's tile names each workflow of its commit with its own
verdict.

## Why

The third move (2026-11-08), findings 8, 14 and 16, decided by the operator that evening, with the designs *Agents and
providers* and *Third move findings, before and after* (pairs 14 and 16).

## Acceptance

- **Agents & providers** (finding 8): as the design draws it: a head with the count of agents and providers, a filter
  and *Providers on this machine*; a card with one row per agent (name, command and version, an *installed* chip, a
  fold). An unfolded agent shows its facts as label and value in two aligned columns (*Found at*, *Runs*, *Commits
  as*), then *Machines it needs* as allowed chips and *Asked for and refused* as refused chips, each with its note
  under the chips, left-aligned, and *What it fetches* with its sha256 shortened and a copy button. No centered label.
- **The gate's review** (finding 14): above the files, a card with *Commit*, *Author*, *Committer* and *Trailer* (the
  push's own lines), and a chip that says whether there is exactly one Assisted-by and no Co-Authored-By. Where the
  machine does not report them, the card says so instead of leaving them out.
- **Builds on a tile** (finding 16): one line per workflow of the commit, its name and its verdict (passed, running,
  not started, failed); "Build passed" only when every workflow has passed. Where the machine reports one verdict
  only, that verdict is named by its workflow.

## Size

M: M the agents' page, S the review card (with the push's fields as the machine reports them), S the workflows.

## How it stands

- **Agents & providers:** built as designed. An unfolded agent's facts stand in two aligned columns
  (`FactRows`, one label edge and one value edge; on a phone each label above its value), the hosts it needs and
  those it is refused as chips with their note under them, and what it fetches with `sha256 <first 8>…<last 8>`
  and a button that copies the whole digest. The head, count, filter and *Providers on this machine* were there.
- **The gate's review:** a card above the files with *Commit* (in full), *Author*, *Committer* and *Trailer* for
  each commit of the push, newest first, from `Review`'s `commits`; where the machine lists none there, the head
  commit as `PendingPush` names it (`author`, `committer`, `trailers`); several commits each say their subject. A
  chip per commit says "One Assisted-by, no Co-Authored-By" where the trailer holds exactly that (keys read without
  regard to case, as git does), and otherwise what is wrong: no Assisted-by, more than one, or a Co-Authored-By.
  What the machine does not report (an older daemon, or a list holding anything but text) says "not reported by
  the machine", and the chip then says that Assisted-by and Co-Authored-By cannot be checked here, never that the
  check passed. The fetch into one's own clone follows the files, as drawn. The commit's whole `message` is read for a
  `Co-Authored-By` outside git's trailer block; where the machine does not report it, the check cannot be made. The
  message body itself is not shown.
- **Builds on a tile:** where the machine lists `Build.runs`, one line per run with its name and verdict (passed,
  failed, also `timed_out` and `startup_failure`, running, not started for `queued`, skipped, or as the forge says
  it); two runs of one workflow are two lines. The headline names every failed run, whatever the verdict; says a
  verdict other than `success` as it is ("Build running", "Build unknown"), never "No workflow ran" for a reading
  not yet made; says "<names> not finished" while a run is queued or in progress; "No workflow ran" for no runs
  beside `success`; and passed ("<name> workflow passed", "Every workflow passed") only where the verdict is
  `success` and every run succeeded. Where `runs` is absent (an older machine), the lines are grouped from the jobs'
  `"<workflow> / <job>"` names as before, and the headline is over the runs that exist now, never the whole build:
  "Passed: every workflow that has run", "<name> workflow passed", "<name> failed", "No workflow ran" when every
  one was skipped, and, for a success without jobs, "The machine says passed; its workflows are not reported".
  Not built: *Start it*, which no method of the contract does.
- **Narrow windows:** at 390 wide the agent's facts and the review card stand each label above its value; a
  scenario opens the review at 390 wide with a long author and trailer line, and fails on any overflow.
