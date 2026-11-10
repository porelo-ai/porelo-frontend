# F394 — A Tunnel Forward Only The Person Reaches

```json
{
  "$schema": "issue-1.json",
  "id": "F394",
  "title": "A Tunnel Forward Only The Person Reaches",
  "state": "Analyzed",
  "size": "M",
  "priority": "Medium",
  "rank": 11,
  "blockedBy": [],
  "covers": "What the window forwards from a machine is reached only by the person: a relay of the window's own lets in only the person's connections, the host refusing other sites' requests to the forge's web.",
  "openQuestions": 2
}
```

**Why this size.** a relay of the window's own in front of every forward, the five ssh forwards moved onto private sockets, its tests and a VM run with a second account; the host's part apart.

**What must be true.** What the window forwards from a machine to this computer is reached only by the person the window runs for, not by every other local user of this computer.

## Why

Three of the window's forwards listen on a TCP port of the loopback address, which every local account on this computer reaches, not only the person:

| Forward | Bound here | Reaches | Open while | Who it lets in |
|---|---|---|---|---|
| A host card's tunnel (`lib/src/app/tunnel.dart`, `_cardCommand`) | `127.0.0.1:<webPort>`, `<gitPort>`, `<matrixPort>` from the card | the host's `/run/porelo-forge/web.sock`, `git.sock`, `/run/porelo-matrix/client.sock`, through the person's own ssh login | the tunnel is up | The forge's web socket takes the ssh peer's login as who asks, so any local user is the person on the host's forge. Git over HTTP asks a token always, and Matrix its access token, so there another user reaches the service but not as the person. |
| A machine's homeserver for a project's conversation (`lib/src/app/homeserver_forwards.dart` through `login_forward.dart`) | `localhost:<port>`, IPv4 and IPv6 | the homeserver on the machine | the window runs, for each joined homeserver | Anyone reaching the homeserver's client API; it asks its own access token. |
| An agent's sign-in redirect (`lib/src/app/login_forward.dart`) | `localhost:<port>` | the sign-in's listener on the machine | the sign-in terminal is open | Anyone could send the listener a redirect before the browser does. |

The daemon's own forward is not among them: it is a Unix socket under the window's runtime directory, made `0600` (`tunnel.dart`).

A Unix socket private to the person would close it where the client on this computer can speak to a socket. A browser and a Matrix client cannot: the forge's pages, Element or nheko, and an OAuth redirect all need a TCP address, so for those a socket alone does not do.

## Plan

**One way closes all three on this computer: the window listens itself, and lets in only the person.** ssh no longer binds a
TCP port. Each forward goes to a Unix socket in the window's runtime directory (`0700`, as the daemon's forward already
is), and the window listens on the same `127.0.0.1:<port>`, and on `::1` where it is `localhost`. For each connection it
asks the kernel who opened it, and relays only the person's own to the socket; any other is closed at once.

- **Who opened it, on Linux:** the connection's other end is a socket of this computer. Its row in `/proc/net/tcp` or
  `tcp6`, found by the two ports, names its owner's uid. Equal to the window's own uid, it is the person; anything else,
  or no row found, is refused. It needs no privilege, and it adds nothing to a request.
- **The forge's web** (`tunnel.dart`, `_cardCommand`): `-L <runtime>/web-<card>.sock:/run/porelo-forge/web.sock`, the relay
  on `<webPort>`. The browser keeps `http://<name>.localhost:<webPort>/`.
- **Git over HTTP and the card's homeserver:** the same, on `<gitPort>` and `<matrixPort>`; git and Element see no change.
- **A joined homeserver and a sign-in's redirect** (`login_forward.dart`, `_withSsh`, `loginForwardCommand`):
  `-L <runtime>/login-<port>.sock:localhost:<port>`, the relay on `<port>`. The window binds the port itself, so the check
  before ssh that the port is free, and its race, go; a port taken stays refused in the same words.
- **New:** `lib/src/app/person_only_relay.dart`, the listener, the owner lookup behind an interface, and the relay.
  `tunnel.dart` and `login_forward.dart` raise and end it with their ssh; `Tunnel`'s leftover cleanup removes its sockets
  too.
- **Tests:** the relay with a stand-in lookup (the person's own connection relayed, another uid's closed with nothing
  read from it, an unknown one closed); the lookup against a real connection here (its own uid found); each forward's
  command with its socket. Each is seen red first. On the VM, a second local account's `curl` to each port is refused and
  the person's gets through.

**What this does not close, and is the host's (to ask Agent Machines):**

- **H1 - any web page in the person's own browser:** the forge's web takes the tunnel as who asks, with no cookie. So any
  page the person opens can send a request to `http://<name>.localhost:<webPort>/` and act as them. A name that resolves
  to `127.0.0.1` can do the same through DNS rebinding. The relay cannot tell these apart: they come from the person's own
  browser. The host's front of `web.sock` must refuse a request whose `Host` is not the card's
  `<name>.localhost:<webPort>` (or `127.0.0.1:<webPort>`). For anything that changes state, it must also refuse a request
  whose `Origin` or `Sec-Fetch-Site` is not that same site. This holds whatever the window does, and is the more urgent
  of the two parts.
- **H2 - only if the relay cannot be had on Windows (see *To be checked*):** the forge's web then asks a session of its
  own. The window would open it by a link meant for a single use, minted over the person's private channel. Core would
  add a method on the person's daemon that hands out such a link (**C1**). The host would set a cookie from it
  (`HttpOnly`, `SameSite=Strict`) and refuse a request without one. With the relay, neither is needed.

Core needs nothing for the relay. Its planned gates for the forge (`issues/base/B355` in Core: "`web.sock` (peer's
login) ... *planned* (the forge's gates)") are where H1 belongs.

## Open questions

- **H1 is outside this repository:** does the operator want it asked of Agent Machines now, apart from this issue, since
  every browser page reaches it today?
- **Windows:** if the owner of a connection cannot be read there, or Windows' ssh cannot forward to a Unix socket, does the
  window keep today's loopback port there, saying so, or does it wait for H2?

## To be checked

- Windows: `GetExtendedTcpTable` names the owning process of a loopback connection, and from it its account; whether
  Win32-OpenSSH's `-L` forwards to an `AF_UNIX` socket. Both are measured before Windows is planned.
- Whether a sign-in's listener on the machine sees any change through the relay: the browser's request is relayed byte
  for byte.
