# F107 — Code Comments In The Review

**Status:** Analyzed; blocked by `sokar`'s [B166](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b166), "Line Comments Sent Back To The Agent", for the comment
model, comments with their origin and the local review, and by [B171](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b171), "Forge Review Comments To And
From A Task", for held forge comments and releasing outgoing ones. An agent as reviewer is [B172](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b172), "A
Task That Reviews". Blocked by [F78](README.md#f78) too: comments are written only in its
forge-like review.
**Size:** L - crosses repositories: a new part of `Tasks1` from `sokar`, the review, *Needs you*,
the stand-in and the docs; it is built in parts, the [B166](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b166) part (ways A and B), the [B171](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b171) part (C and
outgoing release), and D once `sokar` [B172](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b172) is built.

**What must be true.** In the review of a waiting push, a person writes comments on lines and reads
the comments of agents and of people on the forge, each marked with where it came from. A comment
from a forge account the project does not list is held and shown, and goes to the task only when the
person releases it. A comment going out to the forge is released by the person, unless the project
switched that off.

## Why

**A comment is a message.** Sokar passes it through the same controls as any other message: the
sluice, a person's release, the journal. Code and commits still travel only through the gate. Four
ways carry comments, and the interface is where a person meets three of them:

| Way | From and to | What the person does in the interface |
|---|---|---|
| A | a person, to the task | writes a comment on a line of the review |
| B | the task's developer, back | reads the reply in the thread |
| C | people on the forge, to the task | reads them; releases a held one |
| D | an agent as reviewer | reads its comments beside the person's |

Comments going out to a pull request, from the developer (B) or the reviewer (D), wait for the
person's release by default.

## The shape

- **In the review of a waiting push** ([F78](README.md#f78)), a
  line can be commented on, on its old or its new side. A thread shows its comments in order, open
  or resolved.
- **Each comment says where it came from:** the person here, an agent (which task, in which role,
  developer or reviewer), or a forge account (which one). It is never drawn as the person's own.
- **A suggestion** is shown as the lines it would put in place of exactly its anchor, as a forge
  shows a suggested change. The interface never applies it: in a task the agent applies it, and the
  result comes through the gate again.
- **Held comments from the forge** are listed apart, with the account and the text, and each can be
  released alone. Nothing is released in a batch the person did not read.
- **Outgoing comments waiting for release** are listed in *Needs you*, as a held message is, with the
  pull request, the line and the text; releasing one sends exactly that one. Where the project
  switched the release off, that is said in the review, and nothing waits.
- **A refusal is Sokar's:** a comment on a line that is not in the named commit, a suggestion beyond
  its anchor or its size, or text the sluice refused, is shown in Sokar's words.

## Plan

- **Waits for the contract:** nothing is built before [B166](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b166)'s methods and fields are in `Tasks1`;
  `doc/Backend-API.md` and `doc/Contract-Gaps.md` take them first.
- **Red first:** a scenario in `test/features/work_handover.feature` that opens a waiting push,
  comments on an added line and finds the comment in the task's thread on the stand-in.
- **The anchor:** `parseUnifiedDiff` in `lib/src/app/diff.dart` keeps each line's old and new
  number from its hunk header, so `DiffLine` can name a side and a line; `test/app/diff_test.dart`
  proves it.
- **The client:** `SokarClient` in `lib/src/client/sokar_client.dart` and `FleetBackend` in
  `lib/src/app/fleet_backend.dart` gain the comment calls; `lib/src/client/models.dart` a comment
  model with its origin (person, agent with task and role, forge account) and a suggestion.
- **The review:** only [F78](README.md#f78)'s forge-like review, once it is built. `Gate` in `lib/src/app/gate.dart`
  reads the push's threads beside `changed`; the review's file and line widgets draw a thread under
  its line,
  each comment with its origin, a suggestion as the lines it puts in place, and a way to comment.
- **Held forge comments ([B171](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b171)):** listed apart in the review and in *Needs you* beside held
  messages (`Attention` in `lib/src/app/attention.dart`), each released alone, as
  `HeldMessageDialog` in `lib/src/ui/held_message_view.dart` releases a held message.
- **Outgoing ones ([B171](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b171)):** `Attention` in `lib/src/app/attention.dart` lists them beside
  `heldMessages` and counts them in `needingSomebody`; `lib/src/ui/attention_view.dart` draws them.
- **The stand-in:** `lib/src/mock/machine.dart` holds threads, held and outgoing comments, and the
  project's switch; refusals come back in Sokar's words through `RefusalView` in
  `lib/src/ui/refusal.dart`.

## Acceptance

- **A comment written in the review reaches the task.** Seen to fail: today's review, which has no
  way to comment.
- **Comments of an agent and of a forge account are marked with their origin.** Seen to fail: a
  scenario where an agent's comment is drawn as the person's.
- **A held forge comment reaches the task only when released.** Seen to fail: a scenario where it is
  delivered without a release.
- **An outgoing comment waits in *Needs you* and goes out only when released**, one at a time; with
  the project's switch off, it is not held. Seen to fail: scenarios for both.
- **A suggestion is shown and never applied by the interface.** Seen to fail: a scenario where
  accepting it changes a file.

## To be checked

- **The contract:** which methods and fields `sokar`'s comment model brings to `Tasks1`, once its
  requirements say so (Agent Core's).
