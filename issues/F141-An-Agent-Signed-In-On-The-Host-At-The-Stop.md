# F141 — An Agent Signed In On The Host At The Stop

**Status:** Idea.

**What must be true.** When `porelo-host up` stops with `agent-login:<agent>` for an agent the
host's vault has no credential for, the interface signs that agent in on the host, as it signs one
in on a machine today: `porelo vault login <agent>` in its sign-in terminal, here over the host's
ssh as the account, with the agent's redirect to `localhost` forwarded to this computer. The next
`up` finds the credential and goes on. Without the interface, `porelo-host` prints the one command
to type, the ssh line with its forward, and never runs a browser flow itself.

## To be checked

- **The stop's shape:** `needs` naming each agent as `agent-login:<agent>` (porelo-host's
  `tasks.yml`), and what the interface shows for more than one.
- **The terminal and the port:** `vault login` runs the agent's own login in a container with a
  terminal, so the ssh is `ssh -t`. The port is known only once the agent prints its URL, so the
  forward is opened then, on the same connection, as the sign-in terminal already does for a
  machine (Core's reading of `AgentLogin`).
- **An agent whose login is a device flow or a pasted code** needs no forward; the terminal alone.
- **Reaching the host:** over its public ssh with the pinned host key, or the VPN once it is up.
- **Seen on a real host** only with a real agent's browser login, which is the operator's sign-in.
