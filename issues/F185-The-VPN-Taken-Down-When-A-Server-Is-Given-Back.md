# F185 — The VPN Taken Down When A Server Is Given Back

**Status:** Review.
**Size:** S - `HostDialog._down` in `lib/src/ui/host_dialog.dart`, `HostRuns` in `lib/src/app/host_runs.dart`, `Attention` in `lib/src/app/attention.dart`, and `AttentionView` in `lib/src/ui/attention_view.dart`.

**What must be true.** Giving a server back takes this computer's `porelo` VPN tunnel down as its
last step in a small terminal (`"Take the VPN down for <server>"`, one `sudo`), and shows *Done.*
only after the tunnel is down. If the person cancels that terminal, the dialog states `"The server
is given back; the VPN on this computer is still up"` and *Needs you* shows a row with *Take the VPN
down*.

## Plan

- **Where it is today.**
  - `HostDialog._down` (`lib/src/ui/host_dialog.dart`, lines 505–567) runs `session.down`, calls
    `owner.confirmDown(widget.project, session)` and `widget.machines.forget(machine)`, and
    `HostDialog._progress` (line 963) immediately displays `'Done.'` (`Key('host-done')`).
  - Nothing in `_down` or `confirmDown` touches `/etc/wireguard/porelo.conf` or the active `porelo`
    WireGuard interface on this computer, leaving a dead tunnel up after the server has been
    destroyed at the provider.
  - `openHostVpnDialog` (`lib/src/ui/host_vpn_dialog.dart`) already runs `hostVpnDownCommand`
    (`sudo wg-quick down porelo`) in a small terminal dialog when `up: false`.
- **Steps.**
  1. In `HostDialog._down` (`lib/src/ui/host_dialog.dart`), after `hostGivenBack(session)` is true
     and `confirmDown` and `machines.forget` have run, check whether this computer still has the
     `porelo` VPN interface up (`probeHostVpnLink` from [F183](README.md#f183)).
  2. When the `porelo` interface is up, open `openHostVpnDialog` (`lib/src/ui/host_vpn_dialog.dart`)
     with `up: false` and title `"Take the VPN down for <server>"` (one `sudo` prompt) before
     marking the give-back dialog finished.
  3. After `openHostVpnDialog` returns, re-check whether the `porelo` interface is down:
     - When it is down, show `'Done.'` (`Key('host-done')`).
     - When the person cancelled the terminal and the `porelo` interface is still up, do not show
       `'Done.'`; instead show `"The server is given back; the VPN on this computer is still up"` in
       the dialog and record the leftover tunnel on `HostRuns` (`lib/src/app/host_runs.dart`).
  4. In `Attention._rows` (`lib/src/app/attention.dart`) and `AttentionView`
     (`lib/src/ui/attention_view.dart`), when `HostRuns` reports a leftover tunnel for a given-back
     server, emit a *Needs you* row naming the server and offering *Take the VPN down* (which opens
     `openHostVpnDialog(..., up: false)` and clears the leftover state once the link is down).
- **Tests, their harm, red first.**
  - *Harm:* leaving the `porelo` WireGuard interface up after the server is destroyed routes
    `10.73.0.1` traffic into a dead tunnel or conflicts with the next server setup, and showing
    *Done.* when the `sudo` step was cancelled hides that the tunnel is still active.
  - In `test/host_dialog_test.dart`, run the give-back flow (`HostDialog.down`) with a fake link
    probe reporting `porelo` up:
    1. When the VPN-down dialog succeeds and the link is down, assert that `'host-done'` appears and
       no *Needs you* row remains.
    2. When the VPN-down dialog is cancelled and the link stays up, assert that `'host-done'` does
       not appear, the dialog shows `"The server is given back; the VPN on this computer is still
       up"`, and `Attention.openRows` contains the leftover-VPN row with *Take the VPN down*.
    Break the post-`down` link check in `HostDialog._down` first and watch the test fail.
  - Words, colors, and layout get no test.

## Acceptance

- When a server is given back while `porelo` is up on this computer, the interface opens `"Take the
  VPN down for <server>"` with one `sudo` prompt as the last step and shows *Done.* only after the
  tunnel is down.
- Cancelling that terminal shows `"The server is given back; the VPN on this computer is still up"`
  and adds a *Needs you* row with *Take the VPN down* that resolves once the tunnel is taken down.
