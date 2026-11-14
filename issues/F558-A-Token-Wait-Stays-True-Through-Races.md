# F558 — A Token Wait Stays True Through Races

```json
{
  "$schema": "issue-1.json",
  "id": "F558",
  "title": "A Token Wait Stays True Through Races",
  "state": "Implementing",
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

## Acceptance

- Each case above has its test, seen red on [F555](README.md#f555)'s code and green after.
