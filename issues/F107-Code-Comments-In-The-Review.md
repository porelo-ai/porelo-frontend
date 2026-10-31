# F107 — Code Comments In The Review

**Status:** Analyzed; blocked by [F78](README.md#f78).
**Size:** M - one review-summary call in the client and its stand-ins, with the contract docs, drawn as one block on
the push's page and one line in its *Needs you* row; no comment model, composer or rendering.

**What must be true.** For each waiting push a person sees, without an IDE, how many findings and review threads are
open and how complete each check is, and never reads a check that is not complete as clean. Comments and findings
themselves are read, written and answered in IntelliJ.

## Why

Whether a push is ready to let through depends on what its checks found and whether they finished. The counts and
completeness are enough for that decision; reading and answering each comment belongs where the code is read.

## Plan

- **Waits for the contract:** the daemon answers, per waiting push, the counts of open findings and open threads, and
  each check run's name, completeness and finding count, from Porelo's review profile in `Tasks1`.
  `doc/Backend-API.md` and `doc/Contract-Gaps.md` take it first.
- **The client:** a small `ReviewSummary` (the two counts, and per run its name, completeness as a plain string and its
  findings) in `lib/src/client/models.dart`, read by `PoreloClient` (`lib/src/client/porelo_client.dart`) and
  `FleetBackend` (`lib/src/app/fleet_backend.dart`); `MockMachine` (`lib/src/mock/machine.dart`) and `FakeBackend`
  (`test/fakes/fake_backend.dart`) hold summaries in every state. A completeness this build does not know is kept as
  the daemon said it.
- **Red first:** a scenario in `test/features/work_handover.feature` with a run that is not complete and has zero
  results, which must not read clean.
- **The push's page:** `Gate` (`lib/src/app/gate.dart`) reads the summary beside `ranked`; `ReviewView`
  (`lib/src/ui/gate_view.dart`) draws a *Checks* block under [F78](README.md#f78)'s header: the two counts, then one
  line per run with its name, its completeness in the daemon's word and its findings, and "Read and answer findings
  and threads in IntelliJ."
- **The *Needs you* row:** the waiting push's row in `AttentionView` (`lib/src/ui/attention_view.dart`) shows the two
  counts and how many checks are not complete.
- **States:** only a complete run with no findings reads "complete · no findings". A run not complete, running,
  failed, not run, or in a state this build does not know shows the daemon's word, never a tick, and zero results under
  it read "0 findings so far". No run reads "No check ran on this push." An older daemon reads "Checks: not
  reported." While it is read, "Reading the checks…". The counts follow the daemon's answer and are never lowered on
  the interface's own account.
- The same summary is what [F112](README.md#f112) and [F190](README.md#f190) show in one line; whichever is built first
  brings the client part.

## What it drops

- Writing comments on lines, ranges, files or the review, the composer, replies, resolving, threads drawn at their
  line or file, outdated threads, origin and source-level badges per comment, suggestions and their previews,
  restricted Markdown rendering, and the full SARIF 2.1.0 result types in the client: move to the IntelliJ plugin's
  code review (`porelo-intellij`).
- Refusals of a comment through `GateProblem`: nowhere; the interface writes no comment.

## Acceptance

- The push's page and its *Needs you* row show the open finding and thread counts and each run's completeness. Seen to
  fail: a scenario in `test/features/work_handover.feature` where a count or a run is missing.
- A run that is not complete, or in a state this build does not know, is never shown as clean, even with zero
  results; no run at all is not shown as clean. Seen to fail: a scenario where such a run reads "no findings" or
  carries a tick.
- An older daemon's missing summary reads "not reported". Seen to fail: a scenario where it reads as zero.

## To be checked

- The method and field names the review summary gets in `Tasks1`, and the profile's words for completeness.
