# F191 — Held And Outgoing Forge Comments Released

**Status:** Idea.

**What must be true.** A comment from an untrusted forge account (`E0`, or `E1` when project or machine policy holds
it) is held and shown in *Needs you* and in the review with its author, forge origin, and source level, and reaches the
task only when the person releases it alone. Comments going out to a forge wait in a release queue and are sent only on
the person's explicit action bound to the exact reviewed commit SHA, target repository, and pull request or merge
request number.

## Why

A stranger's comment on a public pull request (`E0`) can carry prompt injection aimed at an agent (`porelo-project`
[PJ73](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj73)). Holding `E0` comments (and `E1`
comments where policy tightens the default) until a person reads and releases each one keeps untrusted instructions out
of the task while letting the reviewer read them in context. In the other direction, comments written in Porelo must
never leak to an external forge by themselves (`porelo`
[B171](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b171)): they wait until the person releases the
chosen items against the exact reviewed commit and target pull request.

## The shape

- **Inbound held comments (`porelo-project`
  [PJ73](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj73)).** By default, `E0` comments are
  held until the person releases them individually; `E1` and `I1` comments are delivered at once, marked untrusted; `A`
  comments are delivered, marked untrusted. A project file or machine policy may tighten `E1` to held, never loosen
  `E0`.
- **Where held comments appear.** Held comments are listed in *Needs you* and at their anchor in the review, each
  showing its author, forge origin, source level (`E0` or `E1`), and body text, with individual release and dismiss
  actions. Nothing is released in a batch the person did not read.
- **Outbound release queue (`porelo`
  [B171](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b171)).** Comments and replies waiting to go out
  to a forge are listed in *Needs you* and in the review with the target repository, pull request or merge request
  number, file and line anchor, and text. The person can include or exclude each item before releasing, and releasing
  binds the call to the reviewed commit SHA, target repository, and pull request or merge request number. Where a
  project switched outbound holding off, the review states that and nothing waits.

## To be checked

- Dependencies: [F107](README.md#f107), `porelo`
  [B171](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b171), and `porelo`
  [B293](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b293).
- Code places in `porelo-frontend`: `Attention` in `lib/src/app/attention.dart`, `AttentionView` in
  `lib/src/ui/attention_view.dart`, `HeldMessageDialog` in `lib/src/ui/held_message_view.dart`, `Gate` in
  `lib/src/app/gate.dart`, and `ReviewView` and `GateProblem` in `lib/src/ui/gate_view.dart`.
- Which Varlink methods and fields `porelo`
  [B171](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b171) brings to `Tasks1` for held inbound
  comments and commit-bound outbound release.
