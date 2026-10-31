# F191 — Held And Outgoing Forge Comments Released

**Status:** Analyzed.
**Size:** M - two kinds of *Needs you* rows and a read dialog, with list, release, dismiss, send and keep-back calls in
the client and its stand-ins and the contract docs; nothing in the review.

**What must be true.** A comment from an untrusted forge account (`E0`, or `E1` when the project's rule holds it) is
shown in *Needs you* with its author, forge, pull request, source level and text, and reaches the task only when the
person releases that one comment. A comment going out to a forge is shown in *Needs you* with its target repository,
pull request number, file and line, commit and text, and is sent only when the person sends that one comment, bound to
that commit, repository and pull request.

## Why

A stranger's comment on a public pull request (`E0`) can carry prompt injection aimed at an agent; holding it until a
person reads and releases it keeps untrusted instructions out of the task. Comments written in Porelo must never reach
an external forge by themselves.

## Plan

- **Waits for the contract:** the daemon answers held inbound comments (author, forge, pull request, level, body) with
  release and dismiss per comment, the outbound queue (target repository, pull request number, file and line, commit,
  text, and its author: a task, or the person through IntelliJ) with send and refuse per comment, refused when the pull request moved from the commit, and the project's
  outbound holding setting. `doc/Backend-API.md` and `doc/Contract-Gaps.md` take them first.
- **The client:** `HeldForgeComment` and `OutgoingForgeComment` in `lib/src/client/models.dart`, read and decided
  through `PoreloClient` (`lib/src/client/porelo_client.dart`) and `FleetBackend` (`lib/src/app/fleet_backend.dart`),
  with `MockMachine` (`lib/src/mock/machine.dart`) and `FakeBackend` (`test/fakes/fake_backend.dart`).
- **Where:** two rows in *Needs you* (`Attention` in `lib/src/app/attention.dart`, `AttentionView` in
  `lib/src/ui/attention_view.dart`), one per comment, built like `HeldMessageRow` and `HeldMessageDialog`
  (`lib/src/ui/held_message_view.dart`): *Comment held from a stranger* with *Dismiss it* / *Release it*, and *Comment
  waiting to go out* with *Refuse it* / *Send it*, naming its author. A long body shows its first lines and *Read it all* opens the full
  text with the same two buttons.
- **States:** an `E1` comment held by the project's rule says so. While a comment is decided, that row alone shows
  "Sending…" and leaves once the daemon answers. A refusal shows on the row in Porelo's words and the row stays. Where
  the project holds no outbound comments, no outgoing rows show and the project's page says so. A decided row moves to
  the resolved list with its outcome and its buttons disabled, listed for 24 hours. *Refuse it* is final: the comment
  is never sent and its author is told.
- **Safe rendering:** bodies, author names and paths are plain text with Unicode bidi overrides (`U+202A`–`U+202E`,
  `U+2066`–`U+2069`) and control characters (`< 0x20` except `\t` and `\n`, plus `0x7F`–`0x9F`) badged.
- **Red first:** a scenario in `test/features/needs_a_person.feature` with two held comments, releasing one, which must
  send exactly that one.

## What it drops

- Held and outgoing comments shown at their anchor in the review: move to the IntelliJ plugin's review
  (`porelo-intellij`), which releases them there.
- Including or excluding items before one release, and any release of several at once: nowhere; each comment is
  decided alone.

## Acceptance

- Each held comment shows its author, forge, pull request, level and text, and *Release it* sends that one comment
  and no other. Seen to fail: a scenario in `test/features/needs_a_person.feature` where releasing one releases two.
- Each outgoing comment shows its target, pull request number, file and line, commit and text, and *Send it* carries
  that commit, repository and pull request. Seen to fail: a scenario where the call carries another commit or the
  comment goes without *Send it*.
- A person's own outgoing comment, written in IntelliJ, waits and is decided like a task's, and *Refuse it* sends
  nothing. Seen to fail: a scenario where a refused comment is sent, or a person's comment skips the queue.
- A refusal for a moved pull request shows on the row and the row stays. Seen to fail: a scenario where the row leaves
  before the daemon's answer.
- A body with HTML or `U+202E` shows them as text and badges. Seen to fail: a widget test with both in a held comment.

## To be checked

- The method and field names held and outgoing comments get in `Tasks1`.
