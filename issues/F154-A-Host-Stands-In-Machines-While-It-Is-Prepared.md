# F154 — A Host Stands In Machines While It Is Prepared

**Status:** Implementing; reads the plan line of `porelo-host` [HO21](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho21), which gives each
step a plain-words text and its usual duration.
**Size:** M - a run that outlives the dialog, a row under *Machines*, the stop under *Needs you*.

**Order.** In the host flow, after [F152](README.md#f152).

**What must be true.** Starting *Put this project on a server* closes the setup dialog (or says
*Ready: \<name\> is in your machines* without offering *Put it on a server* again) and places the
host in *Machines* at once as *In preparation*, where it becomes a ready machine by itself when
`up` finishes. Its entry shows one plain-words line for the current step, an estimate of the time
left, the full protocol on a click, and *Needs you* with a link to the input when the person is
wanted.

## Why

Today, the host dialog locks the window while `porelo-host up` runs, shows
internal phase names (`rent`, `ssh`, `ansible`), asks *Add this server to your machines* as a
separate step after a finished `up`, and stays open with *Put it on a server* still as its main
button.

## Plan

- **Today**, read in the code: `HostSession` lives only inside `HostDialog`
  (`host_dialog.dart`), so closing the dialog ends what the interface knows of a run. *Machines*
  (`machines_page.dart`) lists only `Machine` entries, each of which opens a `FleetModel` at once;
  nothing can stand there before a daemon exists. `Attention` reads no host run, and `Step` reads
  no `text` or `seconds`.
- **A run that outlives the dialog:** one `HostRuns` model beside `Operations`, holding the
  running `HostSession` per project. *Put it on a server* hands the session to it, and the dialog
  closes. The arguments it ran with are kept on the run (no secret is among them).
- **The host under *Machines* at once:** the page lists each running `up` as its own row, *In
  preparation*, under the project's server name, before any `Machine` exists, so no machine of a
  new kind is stored. The row shows the current step's `text` as `porelo-host` sends it, the time
  left of the whole run and of that step, *Needs you* at a stop, and the
  protocol (every step and the words on standard error) on a click. When `up` ends 0 the row is
  replaced by the `host` machine, added as the dialog adds it today, with no button to press; a
  refusal or a failure keeps the row with its `fix` and the protocol, never marked ready.
- **The stop under *Needs you*:** `Attention` reads `HostRuns`; a waiting run is a row naming the
  project and what the host needs, whose action is [F152](README.md#f152)'s terminal.
- **The run ahead:** the collection writes a first line naming every step ahead in order,
  `{"v": 1, "state": "plan", "steps": [{"task", "text", "seconds"}]}`, `seconds` left out where a
  step has no usual duration, `"when": true` on a step that may be skipped; `down` writes it too. `porelo-host` sends the interface its own
  `plan` line before `rent`, its own steps first, and again with the collection's appended when
  that line arrives. A step is matched by its `task` name, never by position. The run's time left
  is the running step's left plus the sum of the steps after it, an upper bound on a resumed `up`,
  so it reads *about*; a step that may be skipped counts toward it, and is passed over once a
  later step starts.
- **Each relayed field checked, not cast:** `HostRun._relayed` takes `msg`, `task` and `play` with
  `as String?`, so a value of another type would throw in the line handler; each is checked, and a
  malformed line is dropped, with a test on the collection's `plan` line, which carries no `task`.
- **Words come from the lines:** `Step` (`packages/porelo_host`) reads `text` and `seconds`, and
  `porelo-host`'s own steps (`rent`, `ssh`, `copy`, `ansible`) carry theirs in the same lines. No
  view writes a word of its own for a host's step; a step without `text` shows its name.
- **Tests, their harm, red first:** a host never shows as ready unless `up` ended 0 (a person
  sends work to a host that is not there); the stop reaches *Needs you* (a run that waits unseen
  while a rented host bills); the run survives closing the dialog (today it does not).

## Acceptance

- Starting `up` adds the host to *Machines* as *In preparation* with a plain-words step, estimated
  time left, a click to open the protocol, and a *Needs you* link at a stop; when `up` exits 0, the
  host becomes a ready machine by itself and *Put it on a server* is no longer offered as the main
  action.
- Seen to fail: when `up` exits non-zero, the host entry is never marked ready and shows the
  refusal and protocol under *Machines*.

- The step's words and its usual duration come from the collection, through `porelo-host`'s JSON
  step lines; `porelo-host`'s own steps (`rent`, `ssh`, `copy`) get theirs in
  `packages/porelo_host`, in the same lines. The interface's views write no text for a host's step.

## To be checked

- Whether a run survives the interface being closed: `porelo-host` is a child of the interface,
  and what becomes of a rented host when it is killed mid-`up` is measured with the stand-in and
  asked of `porelo-host`'s owner.
