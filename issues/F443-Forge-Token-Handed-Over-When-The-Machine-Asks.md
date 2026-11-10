# F443 — Forge Token Handed Over When The Machine Asks

```json
{
  "$schema": "issue-1.json",
  "id": "F443",
  "title": "Forge Token Handed Over When The Machine Asks",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "The person's forge token on a host made by the host's own command, run in a terminal there from the window when the host asks; never through this program."
}
```

**Why this size.** one more way a start's answer and a build's detail are read, the host's command run in a terminal on
it as the store and import commands are, the machine asked again, and their tests; once the daemon says it.

**What must be true.** When a host needs the person's own forge token for its forge, to tell a task its builds or to
read them for the person, the window says so where the person is, offers the command the host names for making one,
and runs it in a terminal on that host; the work then goes on without a host shell. The token is made on the host by
the host's forge and stays in the person's vault there: it never passes through this program, its socket, a form, a
log or the person's clipboard.

## How it stands

Its Porelo part is on Porelo's main: a missing host forge token is answered on the wire with the vault key and the
host's command, in a start's answer and on a task.

- On a host, the person's forge token for the host's own forge is made by the host: `porelo host forge-token`, run in
  a shell on the host, has the forge make a token for the person's login and puts it into the person's vault there.
  Nobody types or sees it.
- Built in the window: the client reads `CanStart`'s `missing` and a task's `buildsCredential`, each a
  `MissingCredential`; a reply without them reads as nothing missing, and a command with a word that is not plain
  text is neither shown nor run.
- *New work* and *Start an agent for each repository…* show each missing entry beside the start, naming the host and
  the forge, or the vault key where the machine names no forge; the start is not held back. *Store … on <host>, in a terminal there* runs the host's command over
  ssh in the login shell, then asks `CanStart` again.
- A task's detail shows, under its builds and their sentence, the same press; once the command ended with exit code
  0, it says that only the task's next start follows its builds.
- The command runs only on a machine this window reaches over its own ssh, never on this computer, a WSL
  distribution or a socket forwarded by somebody else; there the command is shown to run on the host by hand.
- Reading fixed: a task's store state is its own for each task, machine and entry, and a command's end for one
  opened before lands nowhere; entries sharing a vault key are each shown, the same one once; a host whose ssh
  address starts with a dash offers no press; what the machine names for after the store is said where the window
  does not do it, also where the command is run by hand; and the tests of a WSL distribution reached over ssh and of
  a failed command were made to fail on their own break. Nothing of the reading was declined.
- The forge: Porelo's main names it on each entry as `forge`, by the name the project's `builds.forge` gives it, so a
  start says "<host>'s vault holds no token of yours for github", and the press and its terminal say *Store your
  github token on <host>*, on a start and on a task alike. The client reads it leniently, trimmed, and as none where it
  holds a control or line separator; an entry from an older daemon, or a task kept before the field, names none, and
  the words name the vault key as before.
- Reading of the forge fixed: a forge of blanks or with a control reads as none; entries that differ only by forge
  are each shown, on a start and in the start of the agents; the press names what the sentence names; an entry
  naming neither forge nor key reads as a sentence; and each new test was made to fail on its own break. Nothing of
  the reading was declined.
- Not this issue: the token for the central forge that `porelo-host-push --central` asks for on its terminal; the
  person types that one there.

## Plan

1. The wire, as Porelo serves it: `MissingCredential(for, credential, forge, storeCommand, afterStore)`, with `for`
   `builds` and `afterStore` `ask-again` or `restart` (an unknown value of either shown as it comes), and
   `storeCommand` reading nothing on standard input. `CanStart` carries `missing: []MissingCredential`, which holds
   no start back, each entry `ask-again`, and is empty off a host and with `VAULT_LOCKED`. `Task` carries
   `buildsCredential: ?MissingCredential`, `restart`, while `buildProblem` keeps the sentence.
2. `lib/src/client/models.dart`: `MissingCredential`, `Readiness.missing`, `Task.buildsCredential`; the plain-word
   check shared with the pull requests' missing token.
3. `lib/src/app/missing_credentials.dart`: the command only over the window's own ssh to the host, and the words.
4. `lib/src/ui/missing_credentials_view.dart`, shown by `start_work_view.dart`, `start_agents_view.dart` and
   `panes.dart`; `shell.dart` runs the command in a terminal on the host, then asks `CanStart` again or, for a task,
   says the next start follows the builds.
5. Tests, each seen red first: `test/client/missing_credential_test.dart`, `test/app/missing_credentials_test.dart`,
   `test/ui/missing_credential_view_test.dart`, and scenarios in `task_creation.feature` and `start_agents.feature`;
   the live contract check names the new fields.

## Acceptance

- A start on a host whose person's vault lacks the forge entry says which host and which forge, and offers the host's
  command; after it ran, the machine is asked again and says the entry is there.
- No token is shown, kept, logged, typed or sent over the socket by this program; the terminal shows only what the
  host's command prints.
- The command runs on the host the start is for, never on this computer and never on another machine.

## Open questions

- None; the operator accepted it on 2026-11-09.

## To be checked

- Settled: whether the wire names the forge. Porelo's commit "Name the forge of a missing builds credential" adds
  `forge` to each entry, and a start says it (see How it stands).
- What the host's command says when the person's vault is shut (exit 65, "the vault refused the person's forge
  token; unlock it and retry") and when the person is not admitted yet (exit 69), and whether the window offers the
  vault's opening there as it does for a start; today the terminal shows what the command prints, and the start is
  asked again.
- The live contract check of the new fields, run against a daemon of Porelo's main; so far read only against its
  IDL text.
