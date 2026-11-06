# F394 — A Tunnel Forward Only The Person Reaches

**Status:** Idea.

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

## Open questions

- Which of the three the operator wants closed, and at what cost: the forge's web, where the exposure is the person's identity, first; the others ask their own credential.
- Whether what cannot be a socket gets an address of its own instead: a per-person loopback address, a check of the connecting uid on this computer, or the forge asking a login of its own on that path. Which of these is for Core or the host to do.

## To be checked

- Whether the forge's web socket on a host still takes the ssh peer's login as who asks once the forge's gates are built (planned in Core).
- Whether git over HTTP through the tunnel is used with the person's token from this computer, so a socket for it would need git to reach a socket.
