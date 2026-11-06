# F398 — A Windows Start Leads To The WSL Distribution

**Status:** Estimated.
**Size:** M - "This computer" on Windows as the WSL distribution, the default one read from `wsl.exe`, an older empty
entry taken over by it, the first start's choice where there are several, and their tests with a Windows desk.

**What must be true.** On Windows "This computer" is the person's WSL distribution, reached through `wsl.exe` as a
machine of the kind `wsl` (operator, 2026-11-06: "Für Windows ist WSL = This machine"); the window never lists or
opens a socket entry Windows cannot open.

## Why

On Windows Porelo runs in a WSL distribution, which the window reaches as a machine of the kind `wsl` through
`wsl.exe`. The machine list always starts with `Machine.local()`, which on Windows names no socket (there is no local
daemon); it is opened like any other and refused with "This entry names a socket on a Linux computer, which Windows
cannot open". A stored list replaces it, so a person who had added their distribution never saw it. Since the settings
of the organization model start afresh once (an older `frontend.json` is put aside as `frontend.json.dropped`, never
migrated), the stored WSL entry is gone after that update, the list holds only the unreachable entry, and nothing on
Windows offers the distribution again: it is found only under *Add a machine*, *WSL*.

## Plan

- `lib/src/app/wsl.dart`: `WslDistribution.isDefault`, read from the `*` that `wsl.exe -l -v` puts before the default
  distribution.
- `lib/src/app/machines.dart`: on Windows (`desk.isWindows`) `Machine.local()` is the `wsl` machine of the default
  distribution (`kind: 'wsl'`, its name), found when the list is loaded rather than in the constructor, since
  `wsl.exe` is a process; `isThisComputer` and `listedMachines` take it as this computer, so it is always listed and
  never forgotten, as on Linux. With no distribution at all, no entry, and the empty state below.
- An entry an older build stored on Windows with kind `''` and no socket and no host is dropped when read; a stored
  `wsl` machine of the same distribution, as added by hand today, becomes this computer and is kept once.
- The first start on Windows with several distributions and no default running Porelo: *My machines* offers each, and
  the one chosen is this computer (`askForAMachine(only: MachineKind.wsl)`, `WslSteps`, their checks and the offer to
  set Porelo up). None found says how to install one.
- `doc/index.md`, *Windows*: this computer is the WSL distribution; "Untested on a Windows machine" names the version
  the operator's test ran.
- **The test that goes red first:** `test/app/machines_test.dart` with a Windows `Desk` and a stand-in `Wsl` listing
  `Ubuntu` as default: the first start lists `Ubuntu` as this computer, of kind `wsl`, reached through `wsl.exe`, and
  no socket entry; a stored list with an older empty entry and a hand-added `Ubuntu` reads as one this computer. It
  guards a window that opens to a refusal it cannot fix and a daemon listed twice.

## Acceptance

- A first start on Windows, and one after the settings were put aside, shows "This computer" as the default WSL
  distribution, connected through `wsl.exe`, and no socket refusal.
- A Windows list with a WSL machine opens it as before; Linux is unchanged.
- The Windows runner's suite runs the new tests (no WSL there: the stand-in lists the distributions).

## To be checked

- Whether a distribution without Porelo is offered with the existing setup in `WslSteps`, in the operator's walk.
