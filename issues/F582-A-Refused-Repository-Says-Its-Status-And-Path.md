# F582 — A Refused Repository Says Its Status And Path

```json
{
  "$schema": "issue-1.json",
  "id": "F582",
  "title": "A Refused Repository Says Its Status And Path",
  "state": "Review",
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

## Built

- `lib/src/client/models.dart`: `HostPullRequestRefusal` (repository, reason kept as said, `status` only an int,
  `path` only non-blank text, message); `PullRequestsSeen.refused` drops an entry without a repository or that is no
  map, and is empty from an older machine. `Agent.foundVia` and `signedInThroughTheVault` (`SIGNED_IN` with `vault`).
- `lib/src/app/host_pull_requests.dart`: each answer replaces the project's repository refusals, so one that answers
  again leaves; a refused repository's rows are kept, stale, also on a watch's first answer. `refused` lists the whole
  project's refusal while one stands, otherwise one entry per refused repository. `PullRequestsRefusedRow` says a
  repository refusal with its reason in words (`forge-access`: copy not made yet or not admitted; `forge`: asked
  again; `not-carried`: no longer carried), "The forge answered HTTP <status> when asked for <path>.", the machine's
  words, and that the others still read; its action names the host's administrator. `forge-token` has its own
  sentence and the action "Renew your person token on <host> with porelo host forge-token, in a terminal there.";
  nothing is run.
- `lib/src/app/attention.dart`: a repository refusal's row id ends in `/<repository>`.
  `lib/src/ui/attention_view.dart`: title "Pull requests of <repository> in <project> cannot be read", state
  "Forge token refused" for `forge-token`. `lib/src/ui/start_work_view.dart`: "signed in through the Porelo-Vault to
  <provider>". `FakePullRequestWatch.answer` takes `refused`.
- Tests, each seen red by a deliberate break, then restored from a copy:
  - `test/client/host_pull_requests_test.dart` *a repository refused alone is read with its status and path…*
    (harm: a refusal lost or silencing the others; an older answer read as a refusal). Red with `refused` not read:
    `Expected: an object with length of <2>, Actual: []`.
  - `test/app/host_pull_requests_test.dart` *a refused repository's rows stay, stale…* (harm: the others silenced, or
    its rows vanish as if merged, also on a first answer). Red with rows kept only on later answers:
    `Bad state: No element` at the check after the watch was asked again.
  - same file, *a refused person token says it must be renewed on the host, and how* (harm: a 401 read as an unknown
    refusal). Red without the `forge-token` sentence: `Expected: contains 'refuses your person token'`, actual "…the
    machine refused…".
  - `test/ui/needs_you_pull_request_test.dart` *a refused repository is a row of its own with the forge's status and
    path…* (harm as above, said without repository, status or path). Red with the repository refusals not listed:
    `Found 0 widgets with key [<'attention-row pull requests refused elsewhere/foo/foo-2'>]`.
  - same file, *a refused person token is labelled so and says to renew it on the host*. Red without the state:
    `Found 0 widgets with text "Forge token refused"`.
  - `test/ui/start_agent_found_test.dart` *an agent signed in through the Porelo-Vault says so…* (harm: a vault's
    credential read as the agent's own sign-in on the machine). Red with the vault branch off:
    `Actual: 'Vaulted · signed in here to a-provider'`.
- Not checked: `foundVia` is not in porelo's `40-agent.varlink` at `8192993dd`; it is read from Agent Core's post as
  the Plan cites it, optional, and absent reads as before. No feature was changed; not seen in the debug build. At
  `8192993dd` `HostPullRequestsRefused` carries only `reason` and `message`, so the item below stays open.

## To be checked

- Whether porelo will name a `storeCommand` for `forge-token`, so the window can renew the token as it stores a
  missing one ([F580](README.md#f580)); until then the row says how and runs nothing.
- The reading by another model (Claude Sonnet) found nothing red. Taken from it: the machine's words no longer end
  in two full stops. Left as yellows: no test of two refused repositories at once, of a whole-project refusal hiding
  the repository refusals, or of their clearing when a project is no longer followed (each traced in the code and
  right); the status and path can stand twice, in the window's sentence and in the machine's words; `foundVia` is
  taken from Agent Core's post and is not yet in porelo's wire.
