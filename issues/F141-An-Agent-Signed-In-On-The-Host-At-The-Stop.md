# F141 — An Agent Signed In On The Host At The Stop

**Status:** Estimated.
**Size:** M - the stop's line names the host, the sign-in terminal opened against it with the key
`porelo-host` pinned, and `up` run again after.

**What must be true.** When `porelo-host up` stops with `agent-login:<agent>` for an agent the
host's vault has no credential for, the interface signs that agent in on the host, as it signs one
in on a machine today: `porelo vault login <agent>` in its sign-in terminal, here over the host's
ssh as the account, with the agent's redirect to `localhost` forwarded to this computer. The next
`up` finds the credential and goes on. Without the interface, `porelo-host` prints the one command
to type, the ssh line, and never runs a browser flow itself.

## Plan

- **The stop says where the host is.** `porelo-host`'s waiting step gains the host's address and the
  account, beside `needs` (`{"state":"waiting","needs":["agent-login:pi"],"address":…,"account":…}`).
  It is read in the code from what `up` already holds; nothing else about the host is said.
- **The sign-in terminal, against the host.** The dialog
  ([F135](README.md#f135)'s `lib/src/ui/host_dialog.dart`) opens, for each `agent-login:<agent>` in
  turn, the sign-in terminal the machines' page uses (`lib/src/ui/shell.dart`'s *Log in with …*,
  a `Session` with `forwardsALoginReply`). It runs `porelo vault login <agent>` as the account on the
  host. The reply is forwarded as today: Porelo's `OSC 5379;forward;<port>` raises one forward of
  that port, only in a login's terminal, taken down with it.
- **The host key is the one `porelo-host` pinned.** Its ssh is given `porelo-host`'s own
  `known_hosts` with `StrictHostKeyChecking=yes`, never the person's own file, and the identity the
  person gave `up`. So the interface trusts no other key than `up` did, and writes no
  `known_hosts` of the person's.
- **Then `up` again**, with no answers: the play finds the credential and goes on. A sign-in that is
  cancelled leaves the stop as it was, and the dialog says which agent still waits.
- **Without the interface,** the waiting line's words name the command, e.g. `ssh -t -i <identity>
  -o UserKnownHostsFile=<its known_hosts> porelo@<address> porelo vault login pi`, and say that
  Porelo prints there the forward to run in a second terminal.
- **An agent whose login is a device flow or a pasted code** asks for no forward. The same terminal
  serves it.
- **Tests:**
  - the stop's line carries the address and the account, and no other host fact;
  - one sign-in terminal per agent, in order, against that address with `porelo-host`'s
    `known_hosts`, seen red against the person's own file;
  - the forward raised only from that terminal;
  - `up` run again after the last sign-in, and not after a cancel.

## Acceptance

- Against the VM's `frontend` account, standing in for a host, with the stub agent: the dialog's stop
  for `agent-login:stub` opens the sign-in terminal, the stub's login completes, and the next `up`
  goes on. The stub opens no port, so the forward itself is seen only with a real agent's browser
  login, the operator's.

## To be checked

- **The stop's shape:** porelo-host's `tasks.yml` names each agent as `agent-login:<agent>` after
  porelo's *Whether An Agent Is Signed In, As A Contract*. This issue reads the shape it posts.
- **The account's socket on the host** is not needed for the sign-in; `vault login` talks to the
  account's own daemon there. Confirm in the code that the sign-in terminal needs nothing but ssh.
