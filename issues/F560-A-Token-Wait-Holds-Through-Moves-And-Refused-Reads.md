# F560 — A Token Wait Holds Through Moves And Refused Reads

```json
{
  "$schema": "issue-1.json",
  "id": "F560",
  "title": "A Token Wait Holds Through Moves And Refused Reads",
  "state": "Implementing",
  "size": "S",
  "priority": "Medium",
  "rank": 11,
  "blockedBy": ["F558"],
  "covers": "The races a third reading found in the token wait a machine's page says: a refused read after the token was given, a project's token joining a read begun before it, a page left unread after a press that gave no token, a refusal said after the role went, and an old machine's answer kept for a moved one."
}
```

**Why this size.** The same page and connections as [F558](README.md#f558); each case one guard and one test.

**What must be true.** What a machine's page says of its token wait is the present machine's word to its present
Machine Admin, also where a read is refused or a machine moves while a read is on its way.

## Plan

A third reading of [F558](README.md#f558)'s code found these, left for after its push because the rental waits on it:

- **A refused read after the token.** When the read in `HostConnections.tokenTaken` is refused, `_giveToken` asks a
  second time as root and a passing second read hides the first refusal; two page tests pass only because their stand-in
  ends the wait with `hearTokenWait` instead of `tokenTaken`, and one asks before it connects.
- **A wait that ends without a read.** `_endTokenWait` drops `_askedOnce` only when the kept read said it waits, so a
  wait kept from a connection or the setup leaves the host unasked; for a project's token `tokenTaken` keeps `_asking`
  and joins a read begun before the token was given.
- **A press that gave no token.** While the token is given `_askProgress` stands aside; when the press returns words,
  nothing reads the machine the step may have connected meanwhile.
- **A refusal after the role went.** `_read` returns its refusal even when its answer no longer stands, and `_giveToken`
  then says it at the page's head.
- **A move while a read is on its way.** `_waitsForToken` takes the machine to compare from the organization's view
  rather than the card it asks; `_asking` outlives a move or a removal, so a later ask joins the old machine's read;
  `_askProgress` does not ask again after a move while its own read is still out.

Each gets a test with its harm, red first, in `test/ui/organization_host_pages_test.dart` or
`test/app/organization_connections_test.dart`, with the window's `askOnce` attached as the shell attaches it.

## Acceptance

- Each case above has its test, seen red on [F558](README.md#f558)'s code and green after.
