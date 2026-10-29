# F107 — Code Comments In The Review

**Status:** Analyzed; blocked by [F78](README.md#f78).
**Size:** L - SARIF 2.1.0 review model in `lib/src/client/models.dart`, `PoreloClient`, `FleetBackend`, `Gate`, and
`ReviewView` (`lib/src/ui/gate_view.dart`), with stand-ins and Gherkin scenarios; held inbound and outgoing forge
comment release are split into [F191](README.md#f191).

**What must be true.** In the review of a waiting push ([F78](README.md#f78)), a person writes comments on lines, line
ranges, files, or the review as a whole, and reads the comments and findings of the task's agent, reviewer agents, deterministic tools, and forge accounts
in one SARIF 2.1.0 thread model, Porelo's review profile, each marked with its origin and source
level (`E0`, `E1`, `I1`, `A`, as the daemon reports it), and sees the completeness of
every check run.

## Why

**A comment or finding is a message in one review record.** Whether a person, the task's developer agent, a reviewer
agent, a static analysis tool, or a forge participant wrote it, Porelo carries it in one closed SARIF 2.1.0 profile
with its source level. Holding untrusted inbound forge
comments (`E0`) and releasing outbound comments to a forge are covered in [F191](README.md#f191).

## The shape

- **Closed SARIF 2.1.0 model.** `porelo` validates and serves every review run as a closed SARIF 2.1.0 projection as
  Porelo's written review profile defines it. Every comment or
  finding is a `result` in `runs[].results[]`:
  - Body text in `result.message.text` and optional restricted Markdown in `result.message.markdown`.
  - Severity in `result.level` (`error`, `warning`, `note`, `none`) and category in `result.ruleId`.
  - Anchors in `result.locations[0].physicalLocation`: `artifactLocation.uri` (relative POSIX path, rejecting `..`,
    leading `/`, `\`, drive letters, URL schemes, and `%00`) and 1-based `region` (`startLine`, `endLine`,
    `startColumn`, `endColumn`), with diff side and commit SHA as the profile defines them. Snippets are dropped by the
    profile, so the interface shows no snippet.
  - Threading, reply links, and open or resolved state in `result.properties` as
    the profile defines them; `result.correlationGuid`
    is not used for replies and `result.suppressions` is not used for thread resolution.
  - Provenance and trust in `run.properties` and `result.properties` (source level `E0`, `E1`, `I1`, `A`, origin,
    author role, outdated flag, and review round) are read-only daemon metadata stamped by `porelo`; the interface
    never trusts values supplied by an agent or tool run itself.
- **Check completeness.** `ReviewView` displays the profile's completeness for every `run` as
  the profile defines it; anything but complete is
  never shown as clean, and `suppressions`, `baselineState`, or missing results never make a review clean.
- **Each comment says where it came from:** the person here, the task's agent (`A`), a reviewer agent (`A`), a tool, or
  a forge account (`I1`, `E1`, or released `E0`), each origin as the review profile defines it. It is never drawn as
  the person's own. A reviewer agent's comments come from a stand-in until Porelo runs reviewer tasks; nothing here
  waits for one. By default, `E1`, `I1`, and `A` comments
  are delivered at once and badged as untrusted data; `E0` comments wait for individual release
  ([F191](README.md#f191)).
- **Suggestions.** Proposed code replacements in `result.fixes[].artifactChanges[]` (`deletedRegion` and
  `insertedContent.text`) are shown as the lines they would put in place of their anchor. The interface never applies a
  suggestion automatically: for the person's own comments and `E1`, `I1`, and `A` comments, sending a suggestion back
  to the task requires the person's confirmation, and for `E0` comments no one-click apply action is offered.
- **Safe rendering and size limits.** `result.message.markdown` renders only a restricted safe subset (paragraphs,
  lists, inline code, fenced code blocks, emphasis, and plain text). Raw HTML, inline SVG, remote images (`![]()`),
  auto-executed links, `javascript:` / `data:` / `file:` / `vscode:` / `ssh:` URIs, and Markdown reference links to
  local files are stripped or rendered as inert text. Every string from `message`, `insertedContent`, `uri`, or author
  metadata has Unicode bidi overrides (`U+202A`–`U+202E`, `U+2066`–`U+2069`) and control characters (`< 0x20` except
  `\t` and `\n`, plus `0x7F`–`0x9F`) escaped or badged, within the profile's limits.
- **A refusal is Porelo's:** a comment on a line that is not in the named commit, a suggestion beyond its anchor or its
  size, or text the sluice refused, is shown in Porelo's words through `GateProblem` in `lib/src/ui/gate_view.dart`.

## Plan

- **Waits for the contract:** nothing is built before the comment calls and the review profile
  are in `Tasks1`; `doc/Backend-API.md` and
  `doc/Contract-Gaps.md` take them first.
- **Red first:** scenarios in `test/features/work_handover.feature` that open a waiting push, comment on an added line,
  find the comment in the task's SARIF thread on the stand-in, and verify completeness banners and suggestion
  rendering.
- **The anchor:** `parseUnifiedDiff` in `lib/src/app/diff.dart` keeps each line's old and new 1-based number from its
  hunk header, so `DiffLine` can name a side and a line; `test/app/diff_test.dart` proves it.
- **The client:** add the closed SARIF 2.1.0 review types (`SarifReviewRun`, `SarifResult`, `SarifLocation`,
  `SarifRegion`, `SarifFix`, and the profile's property getters from the profile) to `lib/src/client/models.dart`, and add
  the SARIF review and comment calls to `PoreloClient` in `lib/src/client/porelo_client.dart` and `FleetBackend` in
  `lib/src/app/fleet_backend.dart`.
- **The review:** in [F78](README.md#f78)'s forge-like review, `Gate` in `lib/src/app/gate.dart` reads the push's SARIF
  runs beside `changed` and groups `results` by thread; `ReviewView`, `_File`, `_Line`, and `_Decision` in
  `lib/src/ui/gate_view.dart` draw each run's completeness, draw threads under their line or file (and outdated threads
  when the anchor changed), badge each comment with its origin and source level (`E0`, `E1`, `I1`, `A`), render
  suggestions from `fixes[].artifactChanges[]` without auto-apply (and without one-click apply for `E0`), and provide
  the composer to start a thread, reply, resolve, or reject with open threads.
- **The stand-in:** `MockMachine` in `lib/src/mock/machine.dart` and `FakeBackend` in `test/fakes/fake_backend.dart`
  hold SARIF review runs, threads, and completeness states; refusals come back in Porelo's words through `GateProblem`
  in `lib/src/ui/gate_view.dart`.

## Acceptance

- **A comment written in the review reaches the task as a SARIF result.** Seen to fail: today's review, which has no
  way to comment.
- **Comments and findings of an agent, a reviewer agent (a stand-in), a tool, and a forge account are marked with their origin and
  source level (`E0`, `E1`, `I1`, `A`), and `E1`/`I1`/`A` are marked untrusted.** Seen to fail: a scenario where an
  agent's or forge user's comment is drawn as the person's or without its source-level badge.
- **Every review run shows the profile's completeness as the profile
  defines it, and anything but complete is
  never shown as clean even when `results` is empty.** Seen to fail: a scenario where a non-complete run with zero
  results is shown as clean.
- **A suggestion is shown as a diff against `deletedRegion` and never applied by the interface, with no one-click apply
  action on `E0` comments.** Seen to fail: a scenario where a suggestion modifies a file or offers one-click apply on
  `E0`.
- **Comment bodies and paths strip or disable raw HTML, remote images, dangerous URI schemes, and escape Unicode bidi
  overrides.** Seen to fail: a widget test feeding HTML, a `javascript:` link, and `U+202E` in a SARIF `result`.

## To be checked

- Which Varlink methods and fields the comment calls and the review profile bring to `Tasks1`.
