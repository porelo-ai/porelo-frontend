# F555 — A Machine Says It Waits For Your Token

```json
{
  "$schema": "issue-1.json",
  "id": "F555",
  "title": "A Machine Says It Waits For Your Token",
  "state": "Review",
  "size": "S",
  "priority": "Highest",
  "rank": 5,
  "blockedBy": [],
  "covers": "After Set up a machine stops at the preparation, the machine's own page says the machine waits for the person's forge token and offers Give it your token there, instead of leaving the person to wait for an admission that never comes."
}
```

**Why this size.** One page's part and the answer it reads; no contract.

**What must be true.** When the host answers that it waits for a token, its page says so in the person's words and
offers *Give it your token…* on the page, whatever the setup wizard did before.

## Plan

- **Measured.** On the operator's Ubuntu 26.04 laptop the host's status read failed: the setup had stopped before it
  installed `/usr/sbin/porelo-host`, so `env -i … /usr/sbin/porelo-host org status --json` exited 127. With
  `porelo-host` in place the read answers `waiting-for-token`. Wording that refusal is not part of this issue.
- **What hid the wait.** `_howItStands` in `lib/src/ui/organization_host_pages.dart` showed the token words and
  `organization.giveToken` only from the page's own read (`_progress`). So the wait went unsaid (a) while the window
  was not connected to the host: only "Connect to this machine…"; (b) while the page's read was refused, as with the
  exit 127, or not yet answered, though the last *Connect* had heard `waiting-for-token` and the chip said *Waiting for
  its token*; (c) after *Set up a machine* prepared the host, whose last word - a new host makes no account before its
  first token - was only a notice and was not kept for the page.
- **Built.** `HostConnections` keeps when each host was last heard to wait for its first token
  (`tokenWaitHeard`/`hearTokenWait`): set or cleared by every read that reaches `keepHeard`, by the status read a
  *Connect* makes (`CardHostConnections._waitsForToken`), cleared when a *Connect* comes up, set by the shell's
  `_hostReady` once a setup prepared the host, and cleared by the token's step once the host took a token. A failed
  read and a lost connection keep it; losing the Machine Admin role drops it. The host page says the wait from that
  word (or the last *Connect*'s) wherever its own read says nothing newer: the token words, a line *Last heard at
  HH:MM: … waits for your … token*, saying when not connected that giving the token connects first, and *Give it my …
  token…*, the same `_giveHostToken` as the row's. The chip says *Waiting for its token* then too.
- **The button without a connection.** The token's step connects first (`HostTokenStep.ask` → `_connectHost`), and a
  host waiting for its token is kept connected by *Connect*; where *Connect* is refused, the step says why on its page.
- **Tests.** Widget tests in `test/ui/organization_host_pages_test.dart`: a host not connected and last heard waiting
  shows the line and the button, and gives the token (red on the old page: no button); a host whose last *Connect*
  heard the wait and whose page read is refused offers the button (red on the old page: no button). A unit test in
  `test/app/organization_connections_test.dart`: the wait a *Connect* heard outlasts a disconnect and a status read
  that exits 127, and ends once the connection comes up (red with either record taken out).
- **Read again.** One wait for each host, true to the machine: the page asks one notion, `_waitsForItsToken` (its own
  read, the last *Connect*, or the kept wait), for its words, button, chip and connection line, so a wait the page read
  itself is still said after a disconnect. No longer waiting (`hearTokenWait(waits: false)`) ends every word of it: the
  kept wait, a read that said it waits (asked again once), and the connection's own (`dropTokenWait`, which
  `CardHostConnections` answers with its `_waiting`); a page drops its read of the wait when `tokenWaitEnds` changes,
  and reads again where it can. A connection that comes up, by *Connect* or by a raise of its own, ends it. A kept wait
  holds only for the machine the organization names now (`machineOf`: address, port, host key), so a removed or moved
  host has none; a wait heard while the role was taken is not kept, and losing the role drops the connection's wait
  too. After giving the token the page connects whenever the wait ended, and a press that gave none answers beside
  the button. Tests, each red on the first build: a page read's wait outlasting a disconnect; a token taken with every
  read after it refused; connecting after a token given where the wait was heard elsewhere; the answer beside the
  button; a connection not up while waiting not called down; unit tests for the token taken, a *Connect* or a raise of
  its own coming up, an up *Connect*, a removed or moved host, a role taken during the read, and the role lost.

## Acceptance

- After a setup stopped at the preparation, the machine's page says it waits for the token and *Give it your token…*
  there gives it; the test is seen red on today's code.
