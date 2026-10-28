# F217 — The Laptop's Homeserver Published For The Host While Its VPN Is Up

**Status:** Implementing (sprint 6i); the publishing and the token's part built, on `porelo-host` [HO41](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho41); it reaches a host once a `porelo-host` release carries it and the interface's collection is moved to it.
**Size:** M - the transport's `publish` after the tunnel and `publish --off` at the give-back, the laptop's hosts line
shown, the host's registration token fed at its stop, and their tests; on `porelo-message-matrix` [MX42](https://github.com/porelo-ai/porelo-message-matrix/blob/main/issues/README.md#mx42)'s and `porelo` [B304](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b304)'s published contracts.

**What must be true.** During the move a rented host's tasks reach the project's room on the person's laptop: once
the host's VPN is up, the interface publishes the laptop's own homeserver on the laptop's VPN address under
`matrix.porelo.internal`, gives the host its registration token at the stop, and closes the published address again
when the host is given back. The laptop's own line `127.0.0.1 matrix.porelo.internal` is shown as one marked line for
the person to add once by hand.

## Why

The operator's move keeps the project's room on the laptop while its tasks move to a rented host: `porelo-message-matrix` [MX42](https://github.com/porelo-ai/porelo-message-matrix/blob/main/issues/README.md#mx42) serves the
account's own homeserver on a VPN address (`publish`), `porelo` [B304](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b304) admits another machine to it (`talk admit`), and
`porelo-host` [HO41](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho41) writes the host's side (its hosts line naming the laptop's peer address, and the token at the stop). The
interface brings the VPN up, so it is the one that knows when the address exists. Decided for the laptop's own line
(variant (a)): written once by hand, nothing in the interface writes `/etc/hosts` for it.

## Plan

- **Published after the tunnel:** when `openPreparationVpn` (`lib/src/ui/host_vpn_dialog.dart`) ends with a fresh
  handshake, and on Linux only, the interface runs, in this account,
  `porelo-message-transport-matrix publish --address <peer address>:<port> --name matrix.porelo.internal`:
  - `<peer address>` is `HostUpRecord.vpnPeerAddress` without its prefix; `<port>` is `PORELO_MATRIX_PORT` from
    `~/.config/porelo/matrix/homeserver.conf` (under `$XDG_CONFIG_HOME` where set), since with `--name` the
    published port is the loopback one;
  - only where that file exists, i.e. this account's homeserver was set up; otherwise nothing runs and nothing is
    said;
  - the executable by its path, as `porelo-host` is; its answer `{"published","ca_file","name"}` is read, and what
    it refuses is shown in its words beside the VPN's outcome, never failing the VPN.
- **The laptop's line:** where `/etc/hosts` has no line giving `matrix.porelo.internal` to `127.0.0.1`, the VPN's
  outcome shows the line `127.0.0.1 matrix.porelo.internal # porelo-matrix` with a copy button, to be added once by
  hand; read only, never written.
- **Closed at the give-back:** when the host's `give-back` step is done (`HostSession`, `lib/src/app/host_session.dart`)
  and `homeserver.conf`'s `PORELO_MATRIX_PUBLISH` names this host's peer address, `publish --off` runs; another
  address is left alone.
- **The token at the stop** (`porelo-host` [HO41](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho41)): where `up` asks for `matrix-token`, the stop's terminal runs
  `porelo talk admit <project> <host's machine name> --into <a private temporary file>` in this account, takes the
  registration token from it into the line `matrix-token <base64>` on `porelo-host-stop --stdin`'s standard input, and
  removes the file; the token never reaches a field, argument or log of the interface.
- **Built, the publishing:** `HomeserverPublishing` (`lib/src/app/homeserver_publishing.dart`), owned by `HostRuns` and
  given by the shell on Linux alone. `openPreparationVpn` publishes after a fresh handshake and shows the outcome in a
  dialog of its own (*Your homeserver for this server*), with the laptop's line and a copy button where `/etc/hosts`
  lacks it; `HostRuns.confirmDown` closes it after the confirmed give-back, and a refusal to close stays on the run.
  The port must be one from 1024 on and the peer one plain IPv4 address, or nothing runs. Seen red with each of nine
  faults put back, the publishing before a handshake among them.
- **From its harm reading (nine findings, eight taken, one in part):** the peer address must be a host's in
  `10.73.0.0/16`, written plainly (no wildcard, loopback, broadcast, `.1` or leading zero); a quoted value of
  `homeserver.conf` is read as the value; the transport is stopped after 60 seconds; the VPN's own outcome no
  longer waits on the transport or the dialog; a failed close is said in the host dialog that gave the server back
  as well as on the run. Tests now see a longer address of another host left alone, a port above 65535, a transport
  not installed, the dialog without the line where it is there or nothing was published, *Close*, and nothing
  closed for a give-back not confirmed. **Declined, with the reason:** a test of the shell's one line that gives
  `HostRuns` its publishing on Linux; the walk sees it.
- **From the reading of that fix (eight findings, seven taken):** the transport has one limit, its own: asked to
  end after 60 seconds, killed five seconds later, its output read as far as it came and malformed bytes taken as
  they are; the give-back no longer waits on it: `HostRuns.closeHomeserver` is started after the confirmed give-back
  and waited for only after the VPN's cleanup, and what it says is added to the dialog's words, not put over them.
  Tests now see a transport that sleeps stopped within seconds, the VPN's outcome reached while `publish` is still
  running, and the third and fourth octets refused out of range or with a leading zero. **Declined, with the
  reason:** a widget test of the host dialog showing a failed close: the return value is tested, and walk 19's
  last step sees it.
- **Built, the token at the stop:** where `up` refuses with `matrix-token:` (porelo-host's refusal), the run waits under
  *Needs you* as for `forge-central-token:`. Its terminal reads the host's name over the host's own ssh
  (`/usr/bin/hostname`, as the host's Porelo passes it at its first setup), refuses a name that reads as an option or
  holds what a shell splits, runs `/usr/bin/porelo talk admit <project> <name> --into` a private temporary folder,
  reads `secrets.registration_token` from it with `python3 -I`, and sends `matrix-token <base64>` with the shell's
  own `printf` into `sudo -n porelo-host-stop --stdin matrix-token`; the folder goes with the terminal. A token alone
  asks no master password. Against stand-ins for ssh and Porelo and the real `python3`, the host gets exactly that
  line, and a bad name sends nothing and asks Porelo nothing.
- **Red first:** a test with a scratch `homeserver.conf` and a stand-in transport: after a verified VPN, `publish` ran
  once with exactly that address, port and name; after the give-back, `publish --off` ran; without the file, neither.

## Acceptance

- After the VPN of a host is up, `https://matrix.porelo.internal:<port>` answers on the laptop's VPN address with the
  account's CA, and the host's tasks join the room.
- After the host is given back, the published address is gone and the homeserver serves loopback alone.
- No registration token appears in the interface's settings, logs or arguments.
- Seen to fail: the publish test red before the call exists.
