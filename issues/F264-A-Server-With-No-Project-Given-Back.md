# F264 — A Server With No Project Given Back

**Status:** Accepted.
**Size:** S - `porelo-host` gives back a server it rented with no project, and the interface takes the VPN down only after the give-back was confirmed.

**What must be true.** A server rented by *Prepare a server…* with no project is given back like any other the package rented: the release accepts a server tagged `porelo-host=<name>` as well as `porelo-project=<project>`, and still refuses a server with neither. The interface's take-down asks the give-back first and takes this computer's VPN down (`porelo-<n>`, its `/etc/hosts` line, its CA) only once the give-back is confirmed. A refused give-back leaves the VPN up, says the server is still rented and costing, and names the refusal. A VPN step that did not finish is never reported done.

## Why

Walk 23, step 12-15 (2026-10-30): the give-back was refused with "server c4bd76ba-… carries no porelo-project tag, so it is not this package's to give back", and the server stayed rented. `HostPlan.tag` tags a server with no project `porelo-host=<name>` (`packages/porelo_host/lib/src/host_run.dart`), while `Scaleway.release` accepts only `porelo-project=` (`packages/porelo_host/lib/src/scaleway.dart`). The dialog had run the VPN-down steps first and reported them done, yet `porelo-1` and the `/etc/hosts` line stayed on the Laptop.

## Plan

- `release` accepts either tag prefix; both tags are the package's own.
- The take-down's order: give back, then VPN down, each step's result read, not assumed.
- **Red first:** a fake Scaleway with a `porelo-host=walk9server` server: release deletes it; with no tag it refuses. A take-down whose give-back is refused runs no VPN step.
- The existing provider-first order remains. `host_dialog.dart` shows the continuing rental with the
  refusal; `host_runs.dart` retains cleanup until the root command succeeds and the link is absent.
  Both the take-down dialog and the shell's existing cleanup action report the command result.

## Test

Only the change: the tests above. No rental: the fake Scaleway is the test.

- The host-only ownership test fails before the release fix with `srv-1 carries no porelo-project tag`.
- The refused give-back test opens no VPN terminal and requires the continuing-rental sentence.
- Failure and cancellation after link removal must keep cleanup pending through a fleet refresh;
  the regression fails before the fix because `host-done` is found. A successful retry clears it.
- Targeted checks pass: `scaleway_test.dart` (15), `host_dialog_test.dart` (133),
  `host_restart_test.dart` (10), `host_runs_test.dart` (27), and `application_shell_test.dart` (15).
  None are skipped. `dart analyze` reports no issues; plain `dart format` completes on changed Dart files.

## Deferred

- Exercise pending cleanup through `Shell._changeVpn` instead of a hand-written closure.

## Estimate

`F264 size=S est=15 basis=median S 15 (11 records)`
