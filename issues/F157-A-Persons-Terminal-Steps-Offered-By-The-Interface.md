# F157 — A Person's Terminal Steps Offered By The Interface

**Status:** Analyzed.
**Size:** M - the VPN up and down in a local terminal, the room offered from the host flow, their words.

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

## Plan

- **Today**, read in the code: the host dialog shows the tunnel's settings and saves a `wg-quick`
  file (*Save the wg-quick file*), and nothing brings the tunnel up. The room is already joined
  from the interface, through the contract and not a terminal: the project's *Messages*
  (`messages_view.dart`, `ProjectConversation`) calls the daemon's join and raises the ssh forward
  to the homeserver's port itself (`login_forward.dart`, `HomeserverForwards`), kept while the
  window runs and raised again at the next start. It names the homeserver's address
  `http://127.0.0.1:<port>` and the person's Matrix ID. Nothing in `lib/` runs `porelo talk join`,
  and nothing says how a mention is made.
- **The VPN, with [F150](README.md#f150):** on the `host` machine, *Bring the VPN up* opens a
  terminal on this computer (`runInATerminal` on the local machine) running
  `sudo install -m 600 <the saved file> /etc/wireguard/porelo.conf && sudo wg-quick up porelo`,
  with one line saying it needs root, which `sudo` asks for in the terminal. *Take the VPN down*
  runs `sudo wg-quick down porelo`. The file's path is the one the person saved, checked as a plain
  path and quoted, never spliced. The text of [F150](README.md#f150) moves here, and it is proposed as merged.
- **The room from the host flow:** when `up` has ended and the host is a machine, the host's entry
  offers *Join the project's room*, which opens the existing *Messages* of that project on the
  host. That dialog gains, under its address and Matrix ID, one line on the client: a task is
  mentioned by picking it from the client's list, a pill, not by typing its name.
- **Ready only when it is:** the room shows as joined only once the daemon's join answered and the
  forward is up; a refused join or a forward that did not come up is said in the dialog's own place.
- **Tests, their harm, red first:** a saved path with a quote or a leading dash is refused, not run
  under `sudo` (a command doing the wrong thing as root); the room offer never reads as joined when
  the join was refused. The words get no test.

## Acceptance

- The interface offers guided actions that open a local terminal with the command filled in for the
  `/etc/wireguard` VPN step, `porelo talk join <project> <name>` on the host, and the ssh tunnel to
  the homeserver, followed by the homeserver address, user name, and mention-pill note.
- Seen to fail: when the ssh tunnel or `porelo talk join` fails in the terminal, the step does not
  show the room connection as ready.

## Open questions

- The room is joined through the daemon, not by `porelo talk join` in a terminal: the interface
  already does that and raises the homeserver's forward itself, and the contract forbids running
  the `porelo` CLI for what the daemon offers. Proposed: offer that join from the host flow, and no
  terminal for it.
- The VPN file: installed from the file the person saved, which holds the private key. Proposed:
  after *Bring the VPN up* succeeds, offer to delete that saved file, since `/etc/wireguard` now
  holds it.

## To be checked

- That `sudo install` and `wg-quick up` behave as written under AppArmor on Ubuntu 26.04, measured
  on the VM in `frontend`, which may run `sudo` only for its listed commands, so the measure
  needs the operator's hand or a VM account allowed `wg-quick`.
