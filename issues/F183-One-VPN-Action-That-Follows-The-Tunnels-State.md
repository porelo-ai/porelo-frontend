# F183 — One VPN Action That Follows The Tunnel's State

**Status:** Implementing.
**Size:** S - `lib/src/app/host_vpn.dart`, `HostRuns` in `lib/src/app/host_runs.dart`, `hostMachineCommands` in `lib/src/app/commands.dart`, `lib/src/ui/host_vpn_dialog.dart`, and `lib/src/ui/shell.dart`.

**What must be true.** A server has one VPN tile and menu action whose label and command follow the
tunnel's current state: *Bring the VPN up* when the `porelo` tunnel to that server is not up on this
computer, and *Take the VPN down* when it is. Whether the `porelo` interface exists on this computer
is read without `sudo` (`ip link`), and no `sudo` terminal opens for an action that has nothing to
do.

## Plan

- **Where it is today.**
  - `hostMachineCommands` (`lib/src/app/commands.dart`, lines 683–735) always returns both
    `machine.vpnUp` (*Bring the VPN up*) and `machine.vpnDown` (*Take the VPN down*) for every
    `host` machine, regardless of `vpnUp`.
  - `Shell._machineBody` (`lib/src/ui/shell.dart`, lines 2978–2993) renders both commands side by
    side as `CommandTile`s, and `_machineMenu` puts both in the machine's ⋮ menu.
  - `HostRuns.refreshVpns` (`lib/src/app/host_runs.dart`, lines 122–139) checks only
    `pingHostVpn()` (`lib/src/app/host_vpn.dart`, line 223), which runs `ping -c 1 -W 2 10.73.0.1`
    and does not check whether the local `porelo` network interface exists via `ip link`.
  - `openHostVpnDialog` (`lib/src/ui/host_vpn_dialog.dart`, line 41) always opens a `sudo` terminal
    running `wg-quick down porelo` when *Take the VPN down* is clicked, even when no `porelo` link
    is up on this computer, so the user types a `sudo` password only to see `wg-quick: 'porelo' is
    not a WireGuard interface`.
- **Steps.**
  1. In `lib/src/app/host_vpn.dart`, add an unprivileged link check `probeHostVpnLink` that runs
     `ip link show dev porelo` (without `sudo`) to see whether this computer currently has a
     `porelo` interface, alongside `pingHostVpn` which checks whether `10.73.0.1` answers.
  2. In `HostRuns` (`lib/src/app/host_runs.dart`), track both whether the local `porelo` link is
     present (`vpnLinkUp`) and whether the server answers over it (`vpnUp`), refreshing both in
     `refreshVpns()` and after `openHostVpnDialog` completes.
  3. In `hostMachineCommands` (`lib/src/app/commands.dart`) and `Shell._machineBody` /
     `Shell._machineMenu` (`lib/src/ui/shell.dart`), replace the pair of always-visible commands
     `machine.vpnUp` and `machine.vpnDown` with a single VPN command: *Take the VPN down*
     (`machine.vpnDown`) when the `porelo` interface for this server is up on this computer, and
     *Bring the VPN up* (`machine.vpnUp`) when it is not.
  4. In `openHostVpnDialog` (`lib/src/ui/host_vpn_dialog.dart`), probe `probeHostVpnLink` (and for
     *Bring the VPN up*, whether the tunnel to this server is already up and answering) before
     opening the `sudo` terminal; if the requested state already holds, refresh the state and return
     without opening a `sudo` terminal.
- **Tests, their harm, red first.**
  - *Harm:* opening a `sudo` terminal when `porelo` is already down (or already up for this server)
    prompts for a root password to run a `wg-quick` command that fails or does nothing.
  - In `test/host_vpn_test.dart`, verify that `hostMachineCommands` emits only `machine.vpnUp` when
    the link is down and only `machine.vpnDown` when the link is up, and that `openHostVpnDialog`
    with `up: false` when `probeHostVpnLink` reports no `porelo` interface returns without starting
    a `sudo` terminal session. Break the pre-check in `openHostVpnDialog` first and watch the test
    fail.
  - Words, colors, and layout get no test.

## Acceptance

- A server's page and ⋮ menu show one VPN action at a time: *Bring the VPN up* when the tunnel is
  down, and *Take the VPN down* when the tunnel is up.
- The interface reads whether `porelo` is present on this computer via `ip link` without asking for
  `sudo`.
- Triggering VPN down when `porelo` is already down (or VPN up when it is already up and answering)
  does not open a `sudo` terminal.
