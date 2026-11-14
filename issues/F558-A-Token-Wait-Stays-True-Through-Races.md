# F558 — A Token Wait Stays True Through Races

```json
{
  "$schema": "issue-1.json",
  "id": "F558",
  "title": "A Token Wait Stays True Through Races",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 10,
  "blockedBy": ["F555"],
  "covers": "The token wait a machine's page says stays true where reads, connections and roles change while a read is on its way: no old machine's wait on a re-addressed or re-added host, no wait for someone no longer its Machine Admin, no second root login when the token is given, and every refusal said where it is asked."
}
```

**Why this size.** Edge cases of one page and its connections; each is one guard and one test.

**What must be true.** What [F555](README.md#f555) says on a machine's page is the machine's present word to its present
Machine Admin, whatever happened while a read was on its way.

## Plan

A second reading of [F555](README.md#f555)'s code found these, left for after its push because the operator tests the main path live:

- **Re-addressed or re-added host.** The page's own `_progress` that waited survives a host of the same name moved to
  another address (only `!_isAdminHere` drops it); `_tokenWaits` of a removed host stays and holds again when a host
  of that name comes back with the same reach (`askOnce` only visits `view.hosts`; `tokenWaitHeard` does not drop an
  entry whose machine no longer matches).
- **Role taken during a read.** `_read` keeps a read's answer although `keepHeard` refused it for a person no longer
  admin, and `_waitsForItsToken` does not check `_isAdminHere`; `CardHostConnections._administers` lacks
  `view.holdsRoles`, and `_heard` does not check it after its await; `_turnedAway`'s status read re-establishes a wait
  after the tunnel came up or went meanwhile.
- **Giving the token.** `hearTokenWait(waits: false)` from the token step makes the page start its own read at once,
  beside the step's `connections.progress(host)`: two root logins, and a failing one writes the page's head refusal
  while the dialog is open; `_giveToken` then asks a third time.
- **Refusals in `_giveToken`.** A status read refused after the token was given is dropped when `connect` then
  succeeds; `buttonStays` does not check `connected`, so an answer for a project's wait is lost while not connected.

Each gets a test with its harm, red first, in `test/ui/organization_host_pages_test.dart` or
`test/app/organization_connections_test.dart`.

- **Built.** Every case was real. The page drops its own read when the organization names another machine under its
  name (address, port, host key); `askOnce` drops the kept wait, the read and the asked-once mark of every host the
  organization no longer names. `_read` keeps no answer for someone no longer the Machine Admin, and
  `_waitsForItsToken` says no wait to anyone else; `_administers` asks `holdsRoles`, and `_heard` keeps no answer
  that came after the role was taken. The turn-away's status read says nothing once the connection came up or went
  while it was asked. While the page itself gives the token it starts no read of its own when the wait ends: its press
  takes what the token's step heard. A read refused after the token was given is answered though the connection then
  comes up, and the button stays only where it is shown (`connected` for a project's wait). Tests, each red on the
  code before: a page read of a machine moved since; a wait said to someone not its Machine Admin; a read answered
  after the role was taken; one root login for a token given from the page; a refused read after the token; why no
  project token was given once the connection went; unit tests for a host taken out and added again (its read too,
  red with that drop taken out), an untrusted card asked nothing as root, a read answered after the role was taken,
  and a turn-away answered after the connection came up.
- **Read a third time.** The token's step now reads through `HostConnections.tokenTaken`, which joins every ask
  begun since the wait ended (`ask`); an ask begun before it is no longer joined, as a wait's end lets the next ask
  start anew. So a token taken logs in as root once, with the window's `askOnce` listening and the page open, given
  from the page or the row, connected first or not. While the page gives the token it starts no read of its own; a
  press that gave no token asks nothing; the press's own read marks the machine asked, so the connection after it
  reads nothing more. A wait that ends has the page read again, also after a refused read. Why a project's token was
  not given from its row stands at the page's head. `askOnce` drops the asked-once mark of a host the organization no
  longer names, also after a refused read; only the role, not a missing connection, keeps a read from being kept. A
  turn-away read and a page read keep nothing of a machine moved while they were on their way, and a page read's
  refusal is not said to someone no longer its Machine Admin. Tests, each red before: one login with `askOnce`
  listening, given from the page, from elsewhere, and where the page was not connected; the row's answer; a read
  after a wait ended elsewhere; no login for no token; one read when connected after; a page read answered after the
  move; unit tests for a host added again after a refused read, a read kept once connected before `askOnce`, and a
  turn-away answered after the move.
- **Left.** A dialog closed without a token answers as a given one does, so the press still reads the machine then.
  A read on its way from before the token was taken still keeps its answer when it lands after the wait ended. A host
  taken out and added again at the same address, port and host key is the same machine to this window, so a read on
  its way across that is kept.

## Acceptance

- Each case above has its test, seen red on [F555](README.md#f555)'s code and green after.
