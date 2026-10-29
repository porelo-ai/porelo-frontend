# F219 — An Interface Ended Without Asking Leaves No Forward Behind

**Status:** Analyzed; a bug.
**Size:** S - the forwards this interface raised found again by their socket at the next start, or ended with it, and
their tests.

**What must be true.** The ssh forwards this interface raises for a machine end with it, also where it ends without
asking: `q` in `flutter run`, a crash, a kill. At the next start a forward of this account already up for the same
socket is used or ended, never a second one raised beside it.

## Why

Closing the window takes every forward down: `_letGo` (`lib/src/ui/shell.dart`) answers the exit request with
`Machines.letGoOfTheTunnels` and `letGoOfTheForwards`. An interface ended without that request leaves its `ssh -N -L`
children running. Measured on the laptop after walk 18: the forward to `f148walk` raised at 12:41 local still ran after
`q`, and the restarted interface raised a second one for the same machine beside it.

## Plan

- **Found again at the start:** before raising a forward for a machine, a running `ssh` of this account whose command
  line is one this interface writes (`-N -o BatchMode=yes … -o ControlPath=none -L <the machine's socket>:…`) is
  ended, so the socket is this run's alone; nothing else of the account is touched.
- **Ended with the interface where the platform allows it:** the forward started so that it ends when its parent
  does (on Linux a parent-death signal through a small wrapper), where that holds without a helper of its own.
- **Red first:** a forward left by an interface that was killed is ended at the next start, and only one runs for the
  socket after it.

## Acceptance

- After `q` in `flutter run` and a new start, one forward runs per watched machine.
- Closing the window still takes them all down, as today.
- Seen to fail: the test red with two forwards for one socket before the start ends the old one.
