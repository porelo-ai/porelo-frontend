# F157 — A Person's Terminal Steps Offered By The Interface

**Status:** Accepted.

**Order.** The last of the host flow; merged with [F150](README.md#f150) in its analysis.

**What must be true.** For every step a person otherwise runs in a terminal of their own, the
interface opens a local terminal with the command filled in and a short line saying what it does
and why it uses a terminal: placing the VPN file in `/etc/wireguard` and running `wg-quick up` with
`sudo` (related to [F150](README.md#f150)), running `porelo talk join <project> <name>` on the
host, and keeping the room's ssh tunnel to the homeserver open. Where the project room is offered,
the interface guides through `porelo talk join`, the ssh tunnel, and the client's homeserver
address and user name as one flow, and says that a mention is a pill picked from the client's list,
not typed text.

## Why

Today the person must open external terminals and type commands by hand for the VPN tunnel and for
joining the room, the ssh tunnel to the host's homeserver is mentioned nowhere in the flow, and
nothing says that a mention in the room client must be picked as a pill from its list rather than
typed as plain text.

## Acceptance

- The interface offers guided actions that open a local terminal with the command filled in for the
  `/etc/wireguard` VPN step, `porelo talk join <project> <name>` on the host, and the ssh tunnel to
  the homeserver, followed by the homeserver address, user name, and mention-pill note.
- Seen to fail: when the ssh tunnel or `porelo talk join` fails in the terminal, the step does not
  show the room connection as ready.

## To be checked

- The exact ssh tunnel arguments for the host's homeserver port and how the local terminal pre-fills
  each command so the person only confirms and types their own input.
