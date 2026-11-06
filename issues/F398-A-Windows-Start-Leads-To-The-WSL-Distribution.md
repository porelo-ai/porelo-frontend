# F398 — A Windows Start Leads To The WSL Distribution

**Status:** Review.
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
- `lib/src/app/machines.dart`: on Windows (`desk.isWindows`) `Machine.local()` is the `wsl` machine of
  `Machine.thisComputersDistribution`, found by `Machines.load` (the constructor runs no process); until then, and where
  `wsl.exe` lists none, an entry of the kind `wsl` naming no distribution, which says to install one or choose one under
  *Add a machine*, *WSL*, opens nothing and is never stored. The first WSL machine added then is this computer.
- `Machine.isAlwaysListed`: on Windows the `wsl` machine of that distribution under whatever name it was added, on
  Linux `Machine.local()` as before; `listedMachines`, *My machines* ("This computer", never forgotten or
  disconnected) and the frame's forgetting use it. `isThisComputer` stays the local socket, so certifying and starting
  Porelo here are unchanged for a WSL machine.
- An entry an older build stored with kind `''` and no socket is dropped when read already (`Settings.machines`); a
  stored `wsl` machine of the same distribution, as added by hand today, is this computer and is listed once.
- `doc/index.md`, *Windows*: this computer is the WSL distribution; "Untested on a Windows machine" names the version
  the operator's test ran.
- **The test that goes red first:** `test/app/this_computer_on_windows_test.dart` with a Windows `Desk` and a stand-in
  for the default distribution `Ubuntu`: the first start lists `Ubuntu` as this computer, of kind `wsl`, reached
  through `wsl.exe`, and no socket entry; a stored hand-added `Ubuntu` reads as one this computer. `wsl_test.dart`
  reads the default from `wsl.exe -l -v`. It guards a window that opens to a refusal it cannot fix and a daemon listed twice.

## Found in the reading

- A distribution found at start was opened twice when a list was stored, and a stand-in was put back beside a stored
  distribution when `wsl.exe` could not be asked: this computer is now listed once, after the stored list is read.
- Adding a distribution, under its own or another name, listed and opened it twice: a distribution is one machine
  whatever its name, and the first one added where none was found replaces the stand-in.
- A machine of another kind named like the distribution: this computer is then listed as `WSL <distribution>`.
- The distribution an earlier list found is not kept for a new one.

## Acceptance

- A first start on Windows, and one after the settings were put aside, shows "This computer" as the default WSL
  distribution, connected through `wsl.exe`, and no socket refusal.
- A Windows list with a WSL machine opens it as before; Linux is unchanged.
- The Windows runner's suite runs the new tests (no WSL there: the stand-in lists the distributions).

## To be checked

- In the operator's walk on Windows: *This computer* is the default distribution and connects, and a list stored with
  the hand-added distribution shows it once.
