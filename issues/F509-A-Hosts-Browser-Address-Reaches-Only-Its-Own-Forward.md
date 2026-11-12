# F509 — A Host's Browser Address Reaches Only Its Own Forward

```json
{
  "$schema": "issue-1.json",
  "id": "F509",
  "title": "A Host's Browser Address Reaches Only Its Own Forward",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 21,
  "blockedBy": [],
  "covers": "The forge and homeserver addresses the window gives a browser for a host's card reach only the card's own forward, on IPv6 loopback as on IPv4, never another local program that listens there."
}
```

**Why this size.** S: the card's forwards held on both loopback families, or the addresses pinned to the one the
forward holds, and their tests.

**What must be true.** A browser or Element that opens the forge or homeserver address the window gives for a host's
card reaches the card's own ssh forward, never another program on this computer, whichever loopback address the name
resolves to first.

## Why

The window gives `http://<host>.localhost:<port>/` for a card's forge and homeserver (`HostCardSsh.forgeUrl` and
`matrixUrl`, `packages/porelo_host/lib/src/host_card_ssh.dart`). Browsers resolve `*.localhost` to `::1` as well as
`127.0.0.1` and may try `::1` first. The card's forwards bind only `127.0.0.1:<port>` (`-L 127.0.0.1:…` in
`lib/src/app/tunnel.dart`). Any program of any account on this computer that listens on `[::1]:<port>` then receives
the person's forge and homeserver sign-ins. Found by a security reading of the Windows card tunnel; it holds on Linux
as built today.

## Plan

- The card's forwards listen on both loopback families: a second `-L [::1]:<port>:<socket>` beside each
  `127.0.0.1` one, with `ExitOnForwardFailure=yes`, so a port already held on either family fails the tunnel rather than
  leaving the other family to someone else. Where the system has no IPv6 loopback, the name must not resolve to it:
  then the address the window gives is `http://127.0.0.1:<port>/`, said with its reason.
- Red first in `test/app/host_card_tunnel_test.dart`: the card's ssh command forwards each port on `[::1]` as on
  `127.0.0.1`; in `packages/porelo_host/test/host_card_ssh_test.dart`, the addresses given match what the forwards
  hold.

## Acceptance

- With a program listening on `[::1]:<port>` before the card is connected, the tunnel is refused, and no address of
  that port is given to a browser.
- With nothing there, the forge and Element open through `<host>.localhost` as today.

## To be checked

- Whether Element and the browsers the window opens resolve `*.localhost` themselves (RFC 6761) or through the system,
  and in which order.
