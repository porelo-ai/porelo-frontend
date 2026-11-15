# F582 — A Refused Repository Says Its Status And Path

```json
{
  "$schema": "issue-1.json",
  "id": "F582",
  "title": "A Refused Repository Says Its Status And Path",
  "state": "Implementing",
  "size": "S",
  "priority": "High",
  "rank": 15,
  "blockedBy": [],
  "covers": "Story ST362: a host's pull-request read refused for one repository says which, with the forge's status and the path asked, while the others' pull requests still show; a refused person token says it must be renewed; an agent signed in through the Porelo-Vault says so on the start dialog."
}
```

**Why this size.** Two answers read, each with a sentence of its own, in the pull-request model, its *Needs you* row
and the start dialog's agent line; the shapes stand in porelo's own stack.

**What must be true.** When a host's forge refuses one repository's pull requests, the person reads which repository,
what the forge answered and what to do, and still sees the other repositories' pull requests; a forge that refuses
the person's token says it must be renewed; an agent signed in through the Porelo-Vault reads as such when work is
started.

## Plan

- **The shapes**, read in porelo's local stack (`8192993dd`, B782, `wire/.../35-gate.varlink` and `doc/hosts.md`)
  and in Agent Core's post of B783 (2026-11-15 07:06Z):
  - `PullRequests` and `WatchPullRequests` answer, beside `pullRequests` and `ended`, `refused: ?[]HostPullRequestRefusal`
    `(repository, reason, status: ?int, path: ?string, message)`, present only when a repository was refused. Reasons:
    `forge-access` (403 or 404: its copy is not made yet or the person is not admitted; an administrator of the host
    makes it or admits them), `forge` (any other status: asked again later), `not-carried` (an earlier row of a
    repository the host no longer carries). A refused repository's earlier rows are kept, neither open nor ended,
    until it answers again.
  - `HostPullRequestsRefused` gains the reason `forge-token`: the forge answered 401 for the whole read; the person
    token is renewed with `porelo host forge-token`.
  - `Agents()`: `agents[].found` `SIGNED_IN` with `foundProvider`, and an optional `agents[].foundVia` `vault` where
    the vault holds the provider's credential (absent where the agent's own sign-in files were found). A shut or
    unreadable vault answers `CANNOT_SAY`.
- **Today** the window reads only `pullRequests` and `ended` (`PullRequestsSeen.from`, `lib/src/client/models.dart`)
  and ignores any other field; an unknown refusal reason is said as "the machine refused" with the machine's message
  (`PullRequestsRefusedRow`, `lib/src/app/host_pull_requests.dart`). The start dialog's agent line
  (`StartAgentChoice._mark`, `lib/src/ui/start_work_view.dart`) says "signed in here to <provider>".
- **Steps.**
  - `PullRequestsSeen` reads `refused` leniently (absent or malformed entries are none; unknown reasons kept as said);
    `HostPullRequests` keeps each repository's refusal per project and drops it once the repository answers again.
  - A refused repository's rows the window already shows stay, marked stale, until it answers again, also on a
    watch's first answer (today the first answer replaces the whole list).
  - *Needs you* shows one row per refused repository (or one per project listing them, whichever reads plainer),
    saying the repository, the reason in words, the status and the path, and what to do: `forge-access` names the
    host's administrator making the copy or admitting the person; `forge` that it is asked again; `not-carried` that
    the host no longer carries it. The machine's `message` is shown as the machine's words.
  - `forge-token` in `PullRequestsRefusedRow`: its own sentence and action, that the forge refuses the person's token
    and it is renewed on the host (`porelo host forge-token`); no command is run for it, since the machine names none.
  - `foundVia: vault` with `SIGNED_IN`: "signed in through the Porelo-Vault to <provider>"; without `foundVia` as
    today.
- **Red first** (harm: one repository's refusal silences or hides the others, or a refused repository's pull requests
  vanish as if merged; a 401 reads as an unknown refusal; a vault sign-in reads as a sign-in on the machine): a client
  test of `PullRequestsSeen.from` with and without `refused`; a model test that a refused repository's rows stay, stale,
  and the others answer; a *Needs you* widget test of a refused repository's row with status and path; a row test of
  `forge-token`; a start-dialog test of `foundVia: vault`. Each seen red.

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green.

## To be checked

- Whether porelo will name a `storeCommand` for `forge-token`, so the window can renew the token as it stores a
  missing one ([F580](README.md#f580)); until then the row says how and runs nothing.
