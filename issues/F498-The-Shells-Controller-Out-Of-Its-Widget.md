# F498 — The Shell's Controller Out Of Its Widget

```json
{
  "$schema": "issue-1.json",
  "id": "F498",
  "title": "The Shell's Controller Out Of Its Widget",
  "state": "Estimated",
  "size": "L",
  "priority": "Medium",
  "rank": 20,
  "blockedBy": ["F497"],
  "covers": "Task start, sign-in recovery and gate forwarding moved out of _ShellState into plain classes behind the interfaces the shell holds, each with its unit tests."
}
```

**Why this size.** L: `lib/src/ui/shell.dart` is the window's controller at about 7000 lines; built in M slices, each
green and pushed on its own.

**What must be true.** The window's controller is plain logic proven by unit tests; the shell's widget only shows it.

## Why

The window's tests follow the test pyramid, as the shared rule *Testing and machines* asks. Task start, sign-in
recovery, gate forwarding and more live in `_ShellState`, so they are proven only by booting the whole window. The
measured basis stands in [F499](README.md#f499).

## Decided by the operator (2026-11-12)

- The window's move to the test pyramid is five issues of their own; this one is built after
  [F497](README.md#f497), whose unit tests on `StartWork` and `ShellModel` it builds on.

## Plan

- Task start, sign-in recovery and gate forwarding move from `_ShellState` (`lib/src/ui/shell.dart`) into plain classes
  in `lib/src/app`, behind the interfaces the shell already holds (`Machines`, `Gate`, `StartWork`). One M slice each,
  then the rest of the controller the same way.
- **Red first:** the task start's unit test in `test/app` over fakes of those interfaces, before the class it names
  exists.
- Each slice removes the shell's widget tests it makes redundant, in the same commit.
- After each slice the shares are measured again as [F499](README.md#f499) says and written there.

## Acceptance

- Task start, sign-in recovery and gate forwarding have unit tests over fakes, each seen to fail with its flow broken;
  `_ShellState` holds none of their logic.
- The shell's widget tests left show only what the widget adds.
