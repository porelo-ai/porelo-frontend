# F171 — The Stop Opens Its Own Small Dialog

**Status:** Review.
**Size:** M - a dialog of its own for the stop, the host's stop script called through the pinned collection, the command line out of sight.

**What must be true.** *Complete setup on the host* opens a small dialog saying only what the host
needs (the Tresorit login, the vault), the Tresorit e-mail and *Open the terminal*; the terminal asks
the login again in place until it succeeds or the person cancels, then the vault; the protocol stays
with the run, and no ssh command line shows unless asked for.

## Plan

- **Today**, read in the code: the *Needs you* row and *Machines* both open the run's whole
  protocol dialog (`host_dialog.dart` `openHostRunDialog`), with the stop's prompts, e-mail field and
  terminal button below it (`_askForTheStop`), out of view on opening. The terminal runs
  `hostStopCommand` (`packages/porelo_host/lib/src/host_stop_command.dart`), one login chained with
  `&&` to the vault, so a typo ends it. `runInATerminal` shows the joined ssh command
  (`unlock_terminal.dart`).
- **The dialog:** `HostStopDialog`, opened by *Complete setup on the host*: the needs in words, the
  e-mail field when `drive` is named, *Open the terminal*, *Show the setup protocol* (opens the
  run's dialog). Closing it keeps the stop.
- **The terminal:** `hostStopCommand` becomes `porelo-host-stop [--email <e-mail>] <needs…>` (each
  argument quoted, the e-mail checked by `isHostDriveEmail` as today), the script the collection
  installs ([HO25](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho25)). The
  interface pins the porelo-host release that carries it (`collection.dart`: version and digest).
  Exit 0: *The host has what it needs; setup goes on*, and `up` runs again; 75: *Cancelled; the
  stop stays under Needs you*, and nothing runs; anything else: its code said, the stop kept.
- **The command line:** `runInATerminal` takes `showCommand: false` here; a *Details* toggle shows
  it.
- **Tests, their harm, red first:** the stop's command names only the known needs and the checked
  e-mail as separate quoted arguments, never a secret (a command doing the wrong thing on the
  host); exit 75 does not run `up` again. Layout gets no test.

## Acceptance

- On the VM and in the guided walk: a wrong password asks again in the same terminal; the dialog
  shows the e-mail field on opening; no ssh line shows until *Details*.
