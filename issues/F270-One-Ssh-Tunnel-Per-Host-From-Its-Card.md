# F270 — One SSH Tunnel Per Host From Its Card

**Status:** Accepted.
**Size:** M - each host reached by one SSH connection written from its card, carrying the forge, Matrix, Git and the daemon, with its state shown.

**What must be true.** For each host card the person may use, the interface writes `$XDG_CONFIG_HOME/porelo/ssh/<host>.conf` (Windows: under APPDATA) with `Host <host>`, HostName, Port, User, `UserKnownHostsFile` holding the card's host key, `StrictHostKeyChecking yes`, `IdentitiesOnly yes` and the person's public key. One ssh connection per host (`-F` that file) forwards: `127.0.0.1:<forge port>` to the forge's web socket, `127.0.0.1:<git port>` to the forge's Git socket (Git over HTTP, as Agent Machines proposed on 2026-10-30), `127.0.0.1:<matrix port>` to the homeserver's socket, the daemon's socket as today, and `-R` to the return socket while the messenger needs it. The forge is reached at `http://<host>.localhost:<forge port>/`, Element at `http://<host>.localhost:<matrix port>`. A host name that is not a lower-case DNS label, or a port another imported host uses, is refused naming both; a port busy at start is said, and no other port is ever chosen. The written file sets `ForwardAgent no`; the KeePassXC agent's socket is never forwarded and never reaches a task. Local forwards bind 127.0.0.1 only (a socket private to the person, where the browser allows it, is to be checked); `-R` goes to the one return socket only. On connect the interface has Core derive the vault share and send it through the tunnel. Each host shows *reached*, *not reached* or *waiting for your key* (KeePassXC locked), never "not answering" for a host reached by SSH.

## Why

One-click joining from signed state (operator, 2026-10-30), building block 2 (everything over SSH) and the contracts agreed in the room with Agent Gorge, Agent Machines, Agent Matrix and Agent IntelliJ (2026-10-30).

## Plan

- Grown from `lib/src/app/tunnel.dart`, which already keeps forwards per machine and ends them ([F219](README.md#f219)).
- The config file is the one contract with the IntelliJ plugin, which passes `-F` to its own ssh calls.
- **Red first:** a test that the written file holds the card's host key, `StrictHostKeyChecking yes` and `ForwardAgent no`; a test that a second host card with a taken port is refused naming both hosts.

## Test

Only the change: tests with the ssh stand-in. One VM check of a real tunnel once porelo-host serves the sockets.

## Estimate

`F270 size=M est=60 basis=median M 61 (24 records)`
