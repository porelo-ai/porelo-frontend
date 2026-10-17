# F126 — The Frame, The Tools And The Workflows Cleared Of The Reading's Findings

**Status:** Backlog; blocked by [F124](README.md#f124).
**Size:** L - twelve findings across `lib/src/ui`, `tool` and the workflows, five of them with a test
for the harm they do, the colours moved into the tokens, the walks translated into US English,
`persist-credentials`, and the documentation in `lib/src/ui`.

**What must be true.** What [F119](README.md#f119)'s reading found in `lib/src/ui`, `tool` and
`.github/workflows` is fixed, or declined in [F119](README.md#f119) with its reason; each fix that
prevents a harm has a test that fails without it; Porelo's look lives in `tokens.dart` alone; the walks
are in US English; and no interface another repository reads changes.

## Plan

- **Findings 13-24 of [F119](README.md#f119)**, one commit each:
  - **with a test, for the harm it prevents:** the shared `GlobalKey` (13) - a crash; the WSL probe
    behind the client (14) - a socket left open; the console's guard (18) - calls piling up ahead of
    the person's own; `tool/e2e.sh` (23) - a run against an empty socket; the Windows signing from the
    certificate store (24) - a secret on a command line and on disk, shown by the Windows job;
  - **fixed without a test,** since none names a harm: what is never disposed or used after it
    (15-17), the dialogs that scroll (19), the lists built lazily (20), *Cancel* (21), the
    diagnosis (22).
- **The colours:** the about forty literals in `theme.dart` and `terminal_look.dart` move into
  `tokens.dart`, and `AGENTS.md` says so beside the rule for sizes. No test holds them there: a colour
  only reads wrong.
- **The walks in US English:** the German sentences in `lib/src/ui/walk_texts.dart` translated, with
  no test.
- **`persist-credentials: false`** on the five checkouts - the job's token left in `.git/config`;
  `check-actions` from porelo-buildtools refuses one without it, run on today's workflows first.
- **`shellcheck` 0.11.0** clean on both scripts, the two trap handlers kept with
  `# shellcheck disable=SC2329` and their reason.
- **The documentation:** each doc comment back on its own member, and every public member of
  `lib/src/ui` documented, held by `public_member_api_docs` for that directory; no test.
- **Red first:** each harm's test, named in its commit; the signing on the Windows job.

## Acceptance

- **Each harm's test fails before its fix and passes after**, or the finding is declined in
  [F119](README.md#f119) with its reason; `theme_contrast_test` stays green.
- **The whole workflow is green on the VM**, and the Windows job signs the MSIX, on the commit
  handed over.
