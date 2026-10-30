# F270 — One SSH Tunnel Per Host From Its Card

**Status:** Implementing. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** M - changes host config, shared transport, saved host state and reachability across the app and host package.

**What must be true.** For each host card the person may use, the interface writes `$XDG_CONFIG_HOME/porelo/ssh/<host>.conf` (Windows: under APPDATA) with `Host <host>`, HostName, Port, User, `UserKnownHostsFile` holding the card's host key, `StrictHostKeyChecking yes`, `IdentitiesOnly yes` and the person's public key. One ssh connection per host (`-F` that file) forwards: `127.0.0.1:<forge port>` to the forge's web socket, `127.0.0.1:<git port>` to the forge's Git socket (Git over HTTP, as Agent Machines proposed on 2026-10-30), `127.0.0.1:<matrix port>` to the homeserver's socket, the daemon's socket as today, and `-R` to the return socket while the messenger needs it. The forge is reached at `http://<host>.localhost:<forge port>/`, Element at `http://<host>.localhost:<matrix port>`. A host name that is not a lower-case DNS label, or a port another imported host uses, is refused naming both; a port busy at start is said, and no other port is ever chosen. The written file sets `ForwardAgent no`; the KeePassXC agent's socket is never forwarded and never reaches a task. Local forwards bind 127.0.0.1 only (a socket private to the person, where the browser allows it, is to be checked); `-R` goes to the one return socket only. On connect the interface opens the host vault with Core's `porelo host unlock <host>` through the tunnel. Each host shows *reached*, *not reached* or *waiting for your key* (KeePassXC locked), never "not answering" for a host reached by SSH.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 2 (everything over SSH) and the contracts agreed in the room with Agent Gorge, Agent Machines, Agent Matrix and Agent IntelliJ (2026-10-30).

## Plan

- **Red first:** extend `test/app/tunnel_test.dart` with two verified host cards sharing a service port. Refuse the second, name both hosts, and observe no config publication or SSH launch for it. This guards connecting a service to the wrong host. Also test the generated config and launch arguments against a fake process before changing transport.
- Cleanup regression tests in `test/app/host_card_tunnel_test.dart` first reproduce a pending trial release killing a concurrently retained master, new consumers starting during old-master teardown, and unused registered or replaced cards keeping their ports reserved. Keep trial ownership through its pending raise, recheck retention before releasing it, serialize teardown with subsequent starts, and record reservation ownership before the first raise.
- Add `HostCardSsh` in `packages/porelo_host/lib/src/host_card_ssh.dart`, using `HostFileWriter` in `packages/porelo_host/lib/src/host_file_writer.dart` and the pinned policy in `packages/porelo_host/lib/src/ssh.dart`. Validate the lower-case DNS label, address, SSH port, public key, socket paths and all local service ports before publication. Write the config, known-host entry and public identity file privately under the required platform config directory. Persist only public card and config references in `lib/src/app/settings.dart` and `lib/src/app/machines.dart` (`Machine`, `Machines`); remove the private identity path requirement for card-based hosts.
- Refactor `Tunnel` and `Tunnels` in `lib/src/app/tunnel.dart` from machine-name ownership to host ownership for imported cards. Serialize concurrent starts, keep card and non-card identities separate, and refuse a second endpoint for an already managed card. Use one owned SSH master and a private control socket so unlock and host commands reuse that connection through `-F`. Configure the three fixed loopback TCP-to-Unix forwards, daemon socket forward and one messenger return socket when its local endpoint is supplied. Remove separate Matrix SSH launches for these hosts from `HomeserverForwards` in `lib/src/app/homeserver_forwards.dart`; keep its callers using the host tunnel. Card-host trials in `lib/src/app/connection_trial.dart` hold the shared master until the last probe finishes; watching a candidate retains its master beyond the probe. Serialize machine-list changes, validate replacement lists before reserving ports, and await active probes and old-master cleanup before adopting replacements. End only processes and endpoints owned here, completing cleanup even when another cleanup or in-flight start fails.
- Card connections go directly through the shared transport and bypass the WireGuard, CA and privileged setup path without changing `lib/src/app/host_vpn.dart`. Delegate `porelo host unlock <host>` to Core after transport connects. Core owns signing, key derivation and secret delivery. Add its app boundary through `lib/src/app/fleet_backend.dart` without parsing CLI output or accepting a secret in a form. Keep SSH reachability separate from daemon readiness in `lib/src/app/fleet_model.dart`; expose host state and public vault refusal for the machine list. Show a daemon or vault refusal beside the reached host.
- Build against the agreed signed host card, Unix service sockets, Core unlock and messenger return behavior behind fakes. These Core and Machines contracts are not implemented yet. The config is also consumed by the IntelliJ plugin through `-F`; preserve that contract. Fail on an unsupported dependency, a busy fixed port or a changed host key. Never select another port.

## Acceptance

- Tests inspect the published files and process arguments: card host key, selected public identity, strict pinning, no agent forwarding, three binds to `127.0.0.1`, daemon forward and exactly one return socket. Malformed card values, duplicate ports within or across hosts, and occupied ports fail before a usable tunnel is reported.
- Concurrent joins of projects on one host start one SSH connection. Unlock and host commands reuse it. Dropping and reconnecting preserves the fixed endpoints. Closing the interface removes its processes and sockets and leaves unrelated forwards alone.
- A locked local key produces *waiting for your key*. A connected SSH host with a stopped daemon remains *reached*, with the daemon failure shown separately. A pin mismatch fails before unlock. No private key, vault share or agent socket enters files, arguments, diagnostics or tasks.
- On a local VM, once the host sockets exist, connect through each advertised service and daemon endpoint and verify the actual listening addresses and cleanup. Record fake coverage separately from this real check.

## To be checked

- Confirm the exact verified card fields, per-account daemon and return socket paths, and Core's unlock invocation and public result. Confirm how Core distinguishes a locked key from denied admission without guessing from a generic SSH refusal.
- Measure OpenSSH public-key selection from the local agent and master reuse on Linux and Windows. Confirm config path quoting, nondefault SSH port pinning and reconnect behavior with the plugin's `-F` calls.
- Check browser and Element behavior for the host's `.localhost` URLs and whether either can use a private local socket. Measure the exposure of loopback ports to other local users; do not silently claim they are owner-only.
- Confirm the machine list consumes `FleetModel.hostState` and `hostProblem` when its separate screen work lands; this change leaves that screen with its assigned builder.

## Implementation boundary

- `HostCardSsh` accepts public values after Core verifies the card; it does not verify signatures or determine admission. Its adapter fields are `name`, `address`, `ssh_port`, `host_key`, `login`, `public_key`, `uid`, `return_socket`, and `services: {forge: {web_port, git_port}, matrix: {port}}`. The account values accompany the verified card rather than becoming signed host-card fields here.
- The daemon endpoint is `/run/user/<uid>/porelo/porelod.sock`, preserving the current daemon filename inside its private runtime directory. The messenger supplies its local socket; the remote endpoint must be one filename under `/run/porelo-host/people/<login>/`.
- Core's command is `porelo host unlock <host>`, with success only on exit zero. Core must consume the published host SSH config and reuse its master. No CLI output is parsed or displayed; nonzero exits carry a generic public refusal until Core supplies a typed public result. `HostUnlocker` supplies that boundary in tests, owns and cancels its child, and permits vault-only retries on the existing master. Every card-backed daemon connection checks transport readiness first, including refresh and automatic retry.
- Linux key availability is checked against the selected public identity with local `ssh-add -L`; a remote SSH refusal never implies a locked local key. Windows config locations are covered, but card transport fails explicitly there until its Unix endpoint and master support is confirmed.
- Publication and Core unlock refuse stored config paths outside the required platform host config directory before changing permissions or launching Core. Messenger endpoints resolve existing ancestors even before the socket exists and compare existing file identities to reject agent hard links. IPv6 zone percent characters are escaped for OpenSSH. Linux local Unix endpoint paths allow at most 107 bytes, leaving the final byte for the terminator.
- The generated config is checked with local `ssh -G` and its public identity with `ssh-keygen -l`. Actual service connectivity, browser behavior and Windows transport are not run. A real-host tunnel check waits for the service sockets and Core unlock implementation.

## Deferred

- Machine-specific references already present in unrelated guided-walk assets, integration and UI tests, and tooling require separate cleanup.
- Review item 9: consuming `FleetModel.hostState` and `hostProblem` in the machine-list screen belongs to its assigned screen builder; the model status and unreachable count distinguish an SSH-reached host from a stopped daemon here.
- Review item 10: identifying a locked signer that still lists its public key requires Core's typed public result; the agreed CLI supplies only success or generic failure, so no exit-code or output meaning is invented here. Explicit `waitingForKey` results already cross the adapter and reach the host model.

## Review corrections

- Items 1 and 8: reject missing-path symlink aliases and existing hard links to the SSH agent; escape accepted numeric IPv6 zone identifiers in `HostName`.
- Items 2 and 3: separate card and legacy tunnel ownership, refuse another endpoint for a managed card, and return transport refusals for invalid local paths and imported port conflicts without leaving a raising state.
- Items 4 and 5: validate replacements before reserving ports, close old watched tunnels on adoption, and release masters and reservations raised only for candidate trials or keyslot counts.
- Items 6 and 7: tolerate disappearing sockets, finish shutdown after rejected raises before reporting the failure, and require publication and Core unlock to use the same platform config location.
- Items 9 and 10: exclude reached or explicitly waiting hosts from the unreachable count, retain a separate daemon refusal, and map Core's explicit signing wait to the host state. Screen wiring and the unagreed Core failure classification remain deferred above.
- Trial cleanup retains its consumer until the pending raise settles and rechecks watchers before teardown. Concurrent drops share cleanup, new starts wait for it, a later drop cancels a queued watcher, and shutdown waits for active teardown before discarding ownership. Host ownership stays reserved until its old master finishes stopping, so another endpoint cannot start against its control socket during cleanup.
- Imported card reservations acquire their machine owner during registration or replacement, so dropping a card before its first raise releases its fixed ports without releasing another endpoint's reservation.

## Test

Only the change: tests with the ssh stand-in. One VM check of a real tunnel once porelo-host serves the sockets.

## Estimate

`F270 size=M est=60 basis=median M 61 (24 records)`
