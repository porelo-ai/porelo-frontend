# F555 — A Machine Says It Waits For Your Token

```json
{
  "$schema": "issue-1.json",
  "id": "F555",
  "title": "A Machine Says It Waits For Your Token",
  "state": "Backlog",
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

- **Seen.** After *Set up a machine* stopped at the preparation, the host answers `waiting-for-token`, but its page
  says nothing of it, and the person waits "for the machine to admit you".
- **Today.** `_howItStands` in `lib/src/ui/organization_host_pages.dart` shows the token words and the button
  `organization.giveToken` only while the host is connected and its `org status` (`SshHostProgress.status`,
  `lib/src/app/host_progress.dart`) was read; not connected, it says only "Connect to this machine to read how far it
  has come". The chip says *Waiting for its token* from the connection or the read. The setup's own last answer
  (`server_setup.dart`) is not kept for the page.
- **Steps.** Measure first which of the two held the page back on the operator's laptop: not connected, or the
  status read failing (see the env refusal under the same page's title). Then the page says the wait from what the
  host last answered - the read, or the setup run's own `waiting-for-token` - and offers *Give it your token…* beside
  it, the same command as the row's; an answer older than the page's read says when it was read.
- **Red first** (harm: a set-up machine never admits anyone, and nothing says why): a widget test of the host page
  with a host whose last answer is `waiting-for-token` and no read since shows the words and the button; it fails on
  today's code.

## Acceptance

- After a setup stopped at the preparation, the machine's page says it waits for the token and *Give it your token…*
  there gives it; the test is seen red on today's code.

## To be checked

- On the laptop: whether the page was not connected or its status read failed, from the window's log.
