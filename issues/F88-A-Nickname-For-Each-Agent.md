# F88 — A Nickname For Each Agent

**Status:** Analyzed; blocked by `sokar` (`@label`, the agent card, and handing the label to the
transport's `enroll --display` and `rename --display`, which `sokar-message-matrix` has built).
**Size:** M - the frontend's part: a field and its check in the start form, `Label` after `Start`,
scenarios, and a step on the VM against Sokar's handover; it waits for `sokar` (`@label`, the agent
card, and the label handed to the transport).

**What must be true.** A person gives each agent a nickname when starting its work, sees it wherever
the agent is shown, and can name the agent by it in the room; the agent knows its nickname too.

## Why

An agent is talked with in three places: its terminal, a direct chat, and the project's room, where
all agents read along and `@` names one. A task name alone is hard to tell apart there.

## The shape

- **The nickname is the task's label** (`Label`), a caption and never a rename: the task's name stays
  its identity and its address. It is set with `Label` right after `Start` (which takes no label), and
  changed on the work's page with the caption dialog that already exists (`panes.dart`).
- **The address stays the task name.** The filter takes only plain names in `metadata.to` and
  `.from`, so a nickname is display only; Sokar resolves `@<nickname>` to the task name before it
  writes `to`.
- **Sokar** resolves `@<label>` to the task, puts `"you": {"task": …, "nickname": …}` into
  `agent-card.json`, tells the agent in its guide to read it there, and hands the label to the
  transport at enrollment and when it changes.
- **The transport** takes it as a display name (`enroll --display`, `rename --display`) and shows it
  in pills. It takes 1 to 64 characters after stripping, no control characters, no `@` and no `:`;
  umlauts, spaces and emoji are fine.

## Plan

- **The field:** `StartWork` in `lib/src/app/start_work.dart` gets a `nickname` beside `name`, and
  a check beside `_localNameProblem`: 1 to 64 characters after stripping, no control character, no
  `@` and no `:`, naming the character it does not take. `ready` stays false while it fails. The
  field goes into the start form in `lib/src/ui/start_work_view.dart`.
- **The label after the start:** `Label` takes the container name, which `Start` does not answer.
  So the shell's `_beginTheRun` in `lib/src/ui/shell.dart` waits for the start to end well, as
  `_workInItOnceUp` does, finds the task of that project and name after a refresh, and calls
  `FleetBackend.labelTask` with its `Task.name` and the nickname; the answer's words are said as
  `_nameTheWork` says them. No nickname, no call.
- **Shown:** the tile and the work's page show `Task.label` already (`lib/src/ui/panes.dart`), and
  `askWhatItReadsAs` changes it later.
- **Red first:** a scenario in `test/features/task_creation.feature`, "work started with a nickname
  has it as its label", that finds `Label` called with the nickname and the label on its tile. Then
  the scenarios for a space or an umlaut, for `@`, `:`, a control character and 65 characters, and
  for no nickname.
- **The room:** measured on the VM against Sokar's handover once both dependencies are on `main`.

## Acceptance

- A nickname given in the start form is set as the task's label after it starts and shown on its tile
  and page. Seen to fail: a scenario in `test/features/task_creation.feature` that starts with a
  nickname and does not find the label set and shown.
- A nickname with a space or an umlaut is taken. Seen to fail: a scenario in
  `test/features/task_creation.feature` that types one and finds it refused.
- A nickname with `@`, `:` or a control character, or longer than 64 characters, is refused as it is
  typed, saying which character is not taken. Seen to fail: a scenario in
  `test/features/task_creation.feature` that types one and finds it taken, or no reason given.
- No nickname given sets no label. Seen to fail: a scenario in `test/features/task_creation.feature`
  that starts without one and finds `Label` called.
- In the room and a direct chat the agent's account shows the nickname, and a person's message naming
  `@<nickname>` reaches that task and wakes it; the agent takes a message naming its task name or its
  nickname as meant for it. Seen to fail: on the VM against Sokar's handover, a message to
  `@<nickname>` in the room that the task does not answer, or an account shown by its task name.

## To be checked

- **Whether the caption dialog `askWhatItReadsAs` takes the same check**, since a label is now a
  display name the transport may refuse. (Agent Frontend's)
- **What is said when the start worked and `Label` was refused**: the work runs without its
  nickname. (Agent Frontend's)
