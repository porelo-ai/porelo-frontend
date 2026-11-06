# F398 — A Windows Start Leads To The WSL Distribution

**Status:** Idea.
**Size:** M - the list's first entry on Windows, the first start's offer of the distributions, a row that says
where to go, their tests with a Windows desk, and the Windows page.

**What must be true.** On Windows the window never lists or opens a "this machine" entry for a daemon Windows
cannot have; with no machine of its own yet, it offers the person's WSL distributions and leads them to connect one,
and a list that holds no WSL machine says where to add it.

## Why

On Windows Porelo runs in a WSL distribution, which the window reaches as a machine of the kind `wsl` through
`wsl.exe`. The machine list always starts with `Machine.local()`, which on Windows names no socket (there is no local
daemon); it is opened like any other and refused with "This entry names a socket on a Linux computer, which Windows
cannot open". A stored list replaces it, so a person who had added their distribution never saw it. Since the settings
of the organization model start afresh once (an older `frontend.json` is put aside as `frontend.json.dropped`, never
migrated), the stored WSL entry is gone after that update, the list holds only the unreachable entry, and nothing on
Windows offers the distribution again: it is found only under *Add a machine*, *WSL*.

## Plan

- `lib/src/app/machines.dart`: on Windows (`desk.isWindows`) the `Machines` constructor adds no `Machine.local()`, and
  `listedMachines` adds no "this computer"; an entry of kind `''` with no socket and no host, as an older build saved
  it, is dropped when read, as an unusable entry already is.
- The first start on Windows with no machine (`lib/src/ui/shell.dart`, the empty state of *My machines*): the
  distributions `Wsl().distributions()` lists, each with *Connect*, which opens *Add a machine* at *WSL* with that
  distribution chosen (`askForAMachine(only: MachineKind.wsl)` and `WslSteps`, their checks and the offer to set Porelo
  up); none found says how to install one.
- The status line and the machine row: where the list holds no WSL machine on Windows, the words name *Add a machine*,
  *WSL*, never a socket.
- `doc/index.md`, *Windows*: the first step after starting it is connecting the distribution; "Untested on a Windows
  machine" says the version the operator's test ran.
- **The test that goes red first:** `test/app/machines_test.dart` with a Windows `Desk`: a first start lists no
  machine the window cannot reach, and a stored list with only an old empty local entry reads as no machine. Then a
  widget test with a stand-in `Wsl` listing `Ubuntu`: the empty state offers it, and *Connect* opens the WSL steps
  for it. They guard a window that opens to a refusal it cannot fix and a person who cannot find their daemon.

## Acceptance

- A first start on Windows, and one after the settings were put aside, shows no "this machine" and no socket refusal;
  it offers the distributions found and connects the one chosen.
- A Windows list with a WSL machine opens it as before; Linux is unchanged.
- The Windows runner's suite runs the new tests (no WSL there: the stand-in lists the distributions).

## To be checked

- Whether a distribution without Porelo is offered with the existing setup in `WslSteps`, in the operator's walk.
