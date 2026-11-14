# F548 — Leftovers Of The Round's Finished Issues

```json
{
  "$schema": "issue-1.json",
  "id": "F548",
  "title": "Leftovers Of The Round's Finished Issues",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 84,
  "blockedBy": [],
  "covers": "What issues finished together named as not built, or what a reading of today's code found beside them, gathered for the operator to place: views that read without the shared reading look, an empty key list that throws, Windows vault unlock bounds, an unused secrets-file setting."
}
```

**What must be true.** What finished issues left unbuilt, each point checked against today's code, is kept in one
place until the operator places each part: in an issue of its own, in a sprint, or dropped. Each point gets no reading
of its own, and is checked against the code again before it is fixed.

## Points

- **Views that read without the shared reading look.** The rule is one look for reading, `Reading`
  (`lib/src/ui/reading.dart`): a bar over the content and, until the first answer, one sentence of what is read. These
  still show words alone or a bare spinner: `lib/src/ui/clearing_view.dart` ("Asking the machine what would go…"),
  `lib/src/ui/grant_view.dart` ("Asking the machine for the page to decide on…"), `lib/src/ui/log_view.dart` (a bare
  `CircularProgressIndicator` until the log answers) and `lib/src/ui/repositories_view.dart` ("Reading the forges set
  up on this computer…"). Others may remain; a search for reading words outside `Reading` finds them.
- **An empty key list throws in the project's forge dialog.** `ProjectForgeDialog` in
  `lib/src/ui/project_forge_view.dart` sets `_key` with `keys.length == 1 || keys.first.gitSigns`: with no key at all,
  `keys.first` throws a `StateError` inside `setState`, so the dialog never says that no key was found.
- **The Windows vault unlock's own bounds** (`lib/src/app/windows_vault_unlock.dart`):
  - the exchange with the OpenSSH agent's pipe is a synchronous `ReadFile` with no timeout, so an agent that never
    answers holds the unlock;
  - a cancel that comes while a host step's ssh is being started leaves that ssh running: `_run` checks `_stillWanted`
    after `_start`, and the process it started is only taken off `_children`, never stopped;
  - nothing calls `WindowsHostUnlocker.rekey`, and `cancel` waits only on pending unlocks, so a rekey would be neither
    serialized with them nor waited for.
- **A secrets file cannot be chosen from the window.** `rememberSecretsFile` in `lib/src/app/settings.dart` has no
  caller in `lib`, so the token step's secrets-file source is read only where the settings already name one.
- **A doc comment above the wrong constant.** In `packages/porelo_host/lib/src/host_run.dart` the comment for
  `rootStillClosed` stands above `hostKeyNotFiled`, and `rootStillClosed` has none.
- **One command still says the bare word.** `organizationAddressCommands` in `lib/src/ui/organization_page.dart` labels
  the creating command 'Create an organization…' beside 'Choose another Porelo organization…'.
- **A temporary apt mirror.** `.github/actions/cached-apt/action.yml` still carries the fallback mirror marked as
  temporary for an outage of Canonical's archive, to be removed once that archive answers again.

- **One forge token in two stores.** A forge's token is kept in the system's secret store for the window's forge API
  and in the Porelo vault for Git (doc/decisions.md, "A forge's token stays on this computer"); one token entered once
  for the organization, the project's opening and *My forges* is not built, and no issue holds it.
- **A broken doc comment.** In `lib/src/ui/terminal_look.dart` a comment on the light console's colours breaks off
  ("… until they read on white, and") and runs into the comment of `screen`.
- **No `i` under *Running*.** The head on *Work* gets no `id` while *Running* shows (`lib/src/ui/work_page.dart`), so
  its explanation cannot be opened there; a terminal needs the height, but the rule that a page's purpose stands
  behind its `i` says otherwise.
- **Counts of one in the plural**: "1 entries" in the vault and its facts, "1 need you" on the side bar and in *Needs
  you*'s subtitle.
- **Older pages and waiting actions under the side bar's tree.** *Managing* of a machine with an organization host's
  card still draws the older admins and facts page; *Put a project on…*, *Store an entry…*, *Propose a card…*,
  *Accept a proposed card…*, *Leave …* and *Join an organization…* are still drawn as actions waiting for a command.
- **Two left as they were by the readers' watch rule.** Two restores of the place in one turn can end each other's
  wait (`lib/src/app/where_you_were.dart`); `work.stop` gives no reason where its machine has no fleet
  (`lib/src/app/commands.dart`).
- **Planner entries that only inform** are not yet routed to the window's log instead of *Needs you*; the planner has
  to say which those are first.

- **The take-down's confirmation names no server.** *Take Porelo off this machine…* and *Return this rental…* say
  "this machine" only (`lib/src/ui/host_dialog.dart`), and no test holds that the dialog keeps its size while the
  host's answers refresh.
- **An organization lives on a forge outside the host**, and the dialog that asks for its address does not say so
  (`lib/src/ui/organization_page.dart`); it names only the https word.

## Open questions

- Where each point goes: an issue of its own, a sprint, or dropped.
