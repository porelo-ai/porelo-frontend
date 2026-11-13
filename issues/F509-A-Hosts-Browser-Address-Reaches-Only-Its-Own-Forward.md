# F509 — A Host's Browser Address Reaches Only Its Own Forward

```json
{
  "$schema": "issue-1.json",
  "id": "F509",
  "title": "A Host's Browser Address Reaches Only Its Own Forward",
  "state": "Review",
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

## Decided

2026-11-13: the forwards hold both loopback families rather than the addresses being pinned to `127.0.0.1`, so the
host's name stays in the browser. The "to be checked" point, which loopback a browser or Element tries first for
`*.localhost`, no longer decides anything: both are the card's own, and where there is no IPv6 loopback the address
names `127.0.0.1` itself.

## How it was built

- `packages/porelo_host/lib/src/host_card_ssh.dart`: `hasIpv6Loopback` reads `/proc/net/if_inet6` once at start
  (elsewhere there is always one); each forward is an `-L` on `127.0.0.1` and, with an IPv6 loopback, on `[::1]`; the
  ports are held on both families before the tunnel starts, so one held by another program on either refuses the card
  and names it; `forgeUrl` and `matrixUrl` give `http://<host>.localhost:<port>/` only while both are held, else
  `http://127.0.0.1:<port>/`.
- `lib/src/app/tunnel.dart`: the card's master runs with `ExitOnForwardFailure=yes`, and a forward ssh raised again on
  one loopback only is cancelled, not left half up.
- `lib/src/app/commands.dart`, `conversation.dart`, `ui/messages_view.dart`, `ui/shell.dart`: the forge, a pull
  request on it and Element are opened only through a forward that is up; while the host's connection is not, Element
  says to connect first and nothing is opened.
- Tests: `packages/porelo_host/test/host_card_ssh_test.dart` (a fixed port held on `::1` by another program refuses
  the card before its tunnel; the browser addresses name only what the forwards hold, with and without an IPv6
  loopback; `::1` found only where Linux lists it); `test/app/host_card_tunnel_test.dart` (the forwards on both
  families, and 127.0.0.1 alone without an IPv6 loopback); `test/app/host_pull_requests_test.dart`,
  `test/app/organization_connections_test.dart`, `test/ui/room_join_through_element_test.dart` (nothing opened while
  the forward is not up).
