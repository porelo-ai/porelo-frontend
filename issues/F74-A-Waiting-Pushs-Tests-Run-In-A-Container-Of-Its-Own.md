# F74 — A Waiting Push's Tests Run In A Container Of Its Own

**Status:** Analyzed; blocked by `sokar` [B95](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b95).
**Size:** M - the frontend's part: an action beside the review, a command kept per project, a
terminal for the run and an acceptance step on the VM; it waits for `sokar` [B95](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b95)'s `gate try`.

**What must be true.** A person can run a waiting push's build or tests, and later open it in an IDE,
in a fresh container on the machine made from the project's image, and read the result beside the
review, without the run reaching the gate.

## Why

Building or testing an agent's work runs whatever the agent wrote; on the person's own computer it
would run with their rights and credentials. `sokar` [B95](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b95) gives `gate try <task> -- <command>`: a fresh
container from the project's image, the waiting ref as its workspace, the project's egress and
limits, no way back to the gate, and an IDE attached there later. An IDE backend on the host is not
offered.

## Plan

- **The action:** `_Decision` in `lib/src/ui/gate_view.dart` gets *Run its tests* beside *Copy the
  diff*, for the push `Gate.looking` holds (`lib/src/app/gate.dart`).
- **The command, asked once:** a dialog asks for it the first time, and a new value in `Settings`
  (`lib/src/app/settings.dart`) keeps it by machine and project; the same dialog changes it.
- **The run:** `gate try <task> -- <command>` is made for the machine with `onTheMachine` in
  `lib/src/app/connections.dart` and run in a terminal with `runInATerminal` in
  `lib/src/ui/unlock_terminal.dart`, so the output streams as it comes. Its exit is said beside the
  review once the run ends.
- **The IDE:** *Open in an IDE* is shown only when Sokar offers it, and attaches to the container of
  that run, by what `gate try` names it.
- **Nothing reaches the gate:** after a run, `Gate.look` reads the push again and the review shows
  the same commit.
- **Red first:** a scenario in `test/features/work_handover.feature`, "a waiting push's tests run in
  a container of its own", against a fake `gate try` in the terminal the test opens, where the
  output or the exit is missing.

## Acceptance

- *Run its tests* beside the review: the command is asked once and kept for the project, run in a
  fresh container, its output streamed and its exit said beside the review. Seen to fail: a scenario
  in `work_handover.feature` against a fake `gate try`, where the output or the exit is missing.
- *Open in an IDE* attaches an IDE to the same container, when Sokar offers it. Seen to fail: a
  scenario where the IDE is attached to anything but that container.
- Nothing the run does reaches the gate: the push stays as the agent made it. Seen to fail: on the
  VM against Sokar's handover, a run that writes to its workspace changes the waiting ref.

## Open questions

- **Whether the command is kept by the interface or in the project's `project.yml`**, where every
  person working on it would share it. (the operator's)

## To be checked

- **Whether `gate try` is reached as a Varlink method** or only as a command on the machine, and
  how its exit and its container are named. (Agent Core's)
- **How Sokar offers an IDE** for the container, and what the interface starts here for it. (Agent
  Core's)
