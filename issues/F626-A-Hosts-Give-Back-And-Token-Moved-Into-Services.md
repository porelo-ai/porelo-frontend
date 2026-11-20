# F626 — A Host's Give-Back And Token Moved Into Services

```json
{
  "$schema": "issue-1.json",
  "id": "F626",
  "title": "A Host's Give-Back And Token Moved Into Services",
  "state": "Estimated",
  "size": "M",
  "priority": "High",
  "rank": 2,
  "blockedBy": [],
  "covers": "Giving a host back and giving its page a token run in services tested without widgets, with their compensation; the dialog and the page keep only busy, problem and the asking"
}
```

**Why this size.** M: two handlers of about 60 and 90 lines with branching and compensation moved into services with
unit tests over their failure paths; no contract changes.

**What must be true.** Giving a host back and giving a host's page its token behave as today, but the steps, their
order and what is undone or read again on failure live in services under `lib/src/app/`, tested without widgets; the
dialog and the page only show busy, the problem and the answer. Second of the four parts begun in
[F625](README.md#f625).

## Plan

Read in today's code.

- `_giveBack` (`lib/src/ui/host_dialog.dart:693`) starts a host session and brings the host down, confirms it
  (`confirmDown`) or reads what was left and forgets the host's record (`forgetHostUp`), removes it from the organization
  with a two-minute limit, forgets each of its machines, and on failure reads the holders and the central again; it
  calls `setState` in its `try` and `finally`. It becomes `HostGiveBack.giveBack` in `lib/src/app/`, answering what
  was done and what failed.
- `_giveToken` (`lib/src/ui/organization_host_pages.dart:621`) branches on what the connection heard before and after
  the token was given, to ask, connect, read the token taken or the page's own read. It becomes one service method
  answering which of these followed.
- Steps: the services' unit tests first, over `FakeBackend` and a fake host session, each failure path (down refused,
  removal timed out, a machine not forgotten) seen red with the logic not yet moved; then the handlers reduced to the
  mapping. Harm guarded: a host given back but still listed, or a machine left behind.

## Acceptance

- The host dialog's and the host page's widget tests pass unchanged; the new unit tests were seen red first.
