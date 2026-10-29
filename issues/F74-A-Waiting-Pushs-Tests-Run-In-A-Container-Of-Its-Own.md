# F74 — A Waiting Push's Tests Run In A Container Of Its Own

**Status:** Analyzed.
**Size:** M - one action in `ReviewView` (`lib/src/ui/gate_view.dart`), a command setting in `Settings`
(`lib/src/app/settings.dart`), and a terminal run in `lib/src/ui/unlock_terminal.dart`, with Gherkin scenarios.

**What must be true.** A person can run a waiting push's build or tests, and later open it in an IDE, in a fresh
container on the machine made from the project's image and pinned to the reviewed commit SHA, with the push's source
level (`E0`, `E1`, `I1`, `A`) and risk class (`C0`–`C3`) shown before launch, and read the
result beside the review without the run reaching the gate or loosening container isolation.

## Why

Building or testing an agent's work runs whatever the agent or external contributor wrote; on the person's own computer
it would run with their rights and credentials. Porelo's
`gate try` runs on a fresh container from the
project's image, pinned to the waiting commit SHA (`PendingPush.commit`), under `porelo`'s isolation, secret
withholding, and egress rules for that push's source level and risk class, with no way back to the gate. An IDE
backend on the host is not offered.

## Plan

- **The action and its isolation notice:** `_Decision` in `lib/src/ui/gate_view.dart` gets *Run its tests* beside *Copy the
  diff*, for the push `Gate.looking` holds (`lib/src/app/gate.dart`). Before launching the container, the dialog
  displays the push's source level (`E0`, `E1`, `I1`, `A`) and risk class (`C0`–`C3`) and states that the trial
  container runs under `porelo`'s isolation rules for that source level and risk class (no task secrets or vault
  credentials, and egress restricted by policy).
- **The command and override bounds:** read by `porelo` from the project's `project.yml` (`repositories.<name>.try`, a
  list of arguments run without a shell). The interface may override the argv list for this computer in `Settings`
  (`lib/src/app/settings.dart`) by machine and project, set and cleared in a dialog that shows the project's own beside
  it (where neither holds one, the dialog asks and keeps the argv list in `Settings`; the interface never writes
  `project.yml`). The override selects only the argv list passed after `--`; it never loosens the source level's
  container isolation, secret
  withholding, or egress rules, and the interface never reads or executes `runs[].invocations[].commandLine` from a
  SARIF file.
- **The commit-pinned argv run:** `gate try` is built for the machine with `onTheMachine` in
  `lib/src/app/connections.dart` as a fixed argv list (never a shell-interpolated string) pinned to the reviewed commit
  SHA (`PendingPush.commit`) and run in a terminal with `runInATerminal` in `lib/src/ui/unlock_terminal.dart`, so the
  output streams as it comes. If the waiting push moved, `porelo` refuses with `MovedSinceReview`
  (`lib/src/app/gate.dart`) and `Gate.look` reloads the review.
- **The IDE:** *Open in an IDE* is shown only when Porelo offers it, and attaches to the container of that run, by what
  `gate try` names it.
- **Nothing reaches the gate:** after a run, `Gate.look` reads the push again and the review shows the same commit.
- **Red first:** a scenario in `test/features/work_handover.feature`, "a waiting push's tests run in a container of its
  own", against a fake `gate try` in the terminal the test opens, asserting that the source level and risk class are
  shown, the command is passed as an argv list pinned to the reviewed commit SHA, and the output and exit are shown.

## Acceptance

- *Run its tests* beside the review shows the push's source level (`E0`, `E1`, `I1`, `A`) and risk class (`C0`–`C3`),
  runs the project's command from `project.yml` or this computer's argv override in a fresh container pinned to
  `PendingPush.commit`, streams its output, and says its exit beside the review; if the push moved, `MovedSinceReview`
  is shown. Seen to fail: a scenario in `test/features/work_handover.feature` where the source level, risk class,
  commit pin, output, or exit is missing.
- The command is passed strictly as an argv list without shell interpolation and never read from SARIF
  `runs[].invocations[].commandLine`. Seen to fail: a test where a shell metacharacter in the override is interpolated
  or `invocations[].commandLine` is read.
- *Open in an IDE* attaches an IDE to the same container, when Porelo offers it. Seen to fail: a scenario where the IDE
  is attached to anything but that container.
- Nothing the run does reaches the gate: the push stays as the agent made it. Seen to fail: on the VM against Porelo's
  handover, a run that writes to its workspace changes the waiting ref.

## To be checked

- Whether `gate try` is reached as a Varlink method or only as a command on the machine, and how its commit pin, exit,
  and container are named.
- How Porelo offers an IDE for the container, and what the interface starts here for it.
