# F462 — A Host's Central Reason Said In Words

**Status:** Implementing.
**Size:** XS - one switch of six known reasons in the words of the repository's row.

**What must be true.** Where the host cannot say how its copy of a repository stands against central, the row says
why in words a person reads, never the daemon's own token.
- Seen live against a rented host (machines-foo, foo-project, 2026-11-09): each repository row of the machine's
  project page read "carried · cannot say: host-answer-refused", the reason as `centralWhy` carries it.
- The contract names the reasons (`20-project.varlink`, `centralWhy`): the host's own `no-read-key`, `unreachable`,
  `no-central-main`, `local`, and Porelo's `host-answer-refused`, `host-command-failed`. New values may appear and
  are shown as they come, after "cannot say".

## Plan

- `lib/src/ui/machine_tree.dart` `centralWords`: `cannot-say` maps each known `centralWhy` to a sentence: the host
  has no read key for central, central cannot be reached from the host, central has no `main`, the repository is the
  host's alone, the host refused to answer, the host's command failed. An unknown one stays as it comes.

## Acceptance

- With the mock answering `central: cannot-say` and each known `centralWhy`, the row says it in words and holds no
  token; an unknown reason is shown as it comes.
