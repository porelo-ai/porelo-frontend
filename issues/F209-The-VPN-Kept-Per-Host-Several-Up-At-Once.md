# F209 — The VPN Kept Per Host, Several Up At Once

**Status:** Review; blocked by [F208](README.md#f208).
**Size:** M - the record moved from project to host with its migration, the root step's names per host, and their tests.

**What must be true.** The VPN this laptop keeps is one per host, not per project: each with its own network `10.73.<n>.0/24`, its own hosts lines and its host's CA, and several hosts' VPNs may be up side by side; a network already up for another host is refused, naming both.

## Why

One host holds several projects, and one laptop reaches several hosts, each with a network of its own (decided: `10.73.<n>.0/24`, a collision refused on the laptop).

## Plan

- **The record:** `HostUpRecord` and `Settings.hostUp(project)`/`rememberHostUp` (`lib/src/app/settings.dart`, `_hostUps`) are keyed by host; a stored record of today is moved once to its host's name, read from its `setupFolder` and address, and kept readable until moved.
- **The interface name:** the WireGuard interface becomes `porelo-<n>` instead of `porelo`, so several are up; `hostVpnUpCommand`, `_vpnRootStep` and `hostVpnDownCommand` (`lib/src/app/host_vpn.dart`) take the interface, the host's name and network as checked arguments; the hosts lines become `forge.<host>.porelo.internal` and `matrix.<host>.porelo.internal` at `10.73.<n>.1`; the CA's store file `porelo-host-<host>.crt`; *down* takes out that host's lines only.
- **The collision:** before the root step, `wg show interfaces` and the routes tell whether another `porelo-*` holds the network; refused with both hosts' names.
- **Red first:** `test/app/host_vpn_command_test.dart` with two hosts' VPNs up in a scratch `/etc`: the second's lines beside the first's, and *down* of one leaving the other's.

## Acceptance

- Two hosts' VPNs up at once on this laptop, each answering, each with its own forge name; one taken down leaves the other untouched.
- A second host on a network already up is refused before any root command, naming both.
- A record kept before this issue is found under its host after the update.
- Seen to fail: the two-host test red before the record is keyed by host.
