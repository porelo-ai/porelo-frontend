# F157 — A Person's Terminal Steps Offered By The Interface

**Status:** Review.
**Size:** M - the VPN up and down in a local terminal, the room offered from the host flow, their words.

**Order.** The last of the host flow.

**What must be true.** The person brings the VPN tunnel to a host up and down from the
interface: a local terminal opens with the command filled in and a short line saying what it does
and why it uses a terminal, since placing the VPN file in `/etc/wireguard` and running `wg-quick`
need `sudo`, which asks there. The project's room is joined from the host's entry through the
interface, with the forward to its homeserver raised by the interface, and the client's
homeserver address, user name and how a mention is made (a pill picked from the client's list, not
typed text) said as one flow.

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
  window runs and raised again at the next start. So the room is joined through the interface, not
  by `porelo talk join` in a terminal. It names the homeserver's address
  `http://127.0.0.1:<port>` and the person's Matrix ID. Nothing in `lib/` runs `porelo talk join`,
  and nothing says how a mention is made.
- **The VPN:** on the `host` machine, *Bring the VPN up* opens a
  terminal on this computer (`runInATerminal` on the local machine) running
  `sudo install -m 600 <the saved file> /etc/wireguard/porelo.conf && sudo wg-quick up porelo`,
  with one line saying it needs root, which `sudo` asks for in the terminal. *Take the VPN down*
  runs `sudo wg-quick down porelo`. The file's path is the one the person saved, checked as a plain
  path and quoted, never spliced. After it came up, the interface offers to delete the saved file, saying it holds the
  private key and now sits in `/etc/wireguard`; it is never deleted unasked.
- **The room from the host flow:** when `up` has ended and the host is a machine, the host's entry
  offers *Join the project's room*, which opens the existing *Messages* of that project on the
  host. That dialog gains, under its address and Matrix ID, one line on the client: a task is
  mentioned by picking it from the client's list, a pill, not by typing its name.
- **Saving after closing setup:** the server's menu offers *Save the VPN connection…* whenever
  its setup record is kept, including after an earlier export. It shares the setup dialog's
  picker, validation and export refusal handling, and keeps the new path only after export.
  When the host becomes Ready, `HostPreparation.tunnel` and `HostSession.address` supply the
  host public key and endpoint address kept in `HostUpRecord`. After a restart the menu rebuilds
  `HostTunnel` from that record; no private key is stored in settings. Older records without
  these optional fields remain valid and explain that the project must be put on a server again
  before saving. Saving or deleting the path preserves both public fields and `collectionSha256`.
- **Ready only when it is:** the room shows as joined only once the daemon's join answered and the
  forward is up; a refused join or a forward that did not come up is said in the dialog's own place.
- **Tests, their harm, red first:** a saved path with a quote or a leading dash is refused, not run
  under `sudo` (a command doing the wrong thing as root); the room offer never reads as joined when
  the join was refused. The words get no test.

## Acceptance

- The host's entry offers *Bring the VPN up* and *Take the VPN down*, each opening a local terminal
  with the command filled in, and *Join the project's room*, opening *Messages* with the homeserver
  address, user name and the mention-pill line.
- Seen to fail: the room never shows as joined unless the daemon's join answered and the forward is
  up; a saved file path with a quote or a leading dash is refused, never run under `sudo`.
- Saving from the server's menu enables *Bring the VPN up*, a refused export leaves the kept path
  unchanged, and choosing another destination replaces the path without losing the collection digest.
- Public tunnel settings round-trip in the kept record, older records still load, and saving from
  the menu works after restarting with fresh settings and no retained run. Completion settings
  are kept only after a successful setup, never from a progress line alone.

## To be checked

- That `sudo install` and `wg-quick up` behave as written under AppArmor on Ubuntu 26.04, measured
  on the VM in `frontend`, which may run `sudo` only for its listed commands, so the measure
  needs the operator's hand or a VM account allowed `wg-quick`.
