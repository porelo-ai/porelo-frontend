# F125 — The Client And The App Cleared Of The Reading's Findings

**Status:** Backlog; blocked by [F124](README.md#f124).
**Size:** L - twelve findings across `lib/src/client`, `lib/src/app` and `lib/src/mock`, eleven of
them with a test for the harm they do, the documentation the reading found misplaced or missing
there, the strict analyzer modes, and `porelo/frontend.json` keeping what it does not know.

**What must be true.** What [F119](README.md#f119)'s reading found in `lib/src/client`, `lib/src/app`
and `lib/src/mock` is fixed, or declined in [F119](README.md#f119) with its reason; each fix that
prevents a harm has a test that fails without it; and no interface another repository reads changes.

## Plan

- **Findings 1-12 of [F119](README.md#f119)**, one commit each, in its order, each test naming the
  harm it prevents:
  - the forge (1-3): the API path joined, not replaced - a request to the wrong address; every
    failure of a request said as `ForgeRefused` - an unhandled failure that leaves a form busy; a time
    limit on each request - a hang;
  - the wire's readers (4-5): no bare cast, a bundle that is not base64 said as a problem - a crash on
    an answer;
  - hand-in (6) - a hang; the forwards (7) - an ssh process left running; the WSL key (8) - a key
    nobody checked trusted for packages; Windows (9-10) - a command run on the wrong machine, a crash;
    two machines of one name in a hand-edited file (12) - calls through another machine's tunnel;
  - the stand-in's `Stop` (11) answers as the daemon does, fixed without a test of its own: it guards
    nothing a person meets.
- **`porelo/frontend.json` keeps the top-level keys it does not know** when it is written
  (`Settings`), as `Machine.fromStored` already keeps a machine's - data lost; with a test.
- **The documentation:** each doc comment back on its own member, and every public member of
  `lib/src/client` and `lib/src/app` documented, held by `public_member_api_docs` and
  `comment_references` for those directories; no test.
- **`strict-casts`, `strict-inference` and `strict-raw-types`** on in `analysis_options.yaml`; they
  find nothing in `lib` today.
- **Red first:** each harm's test, named in its commit; the two Windows findings on the Windows job,
  where only it can show them.

## Acceptance

- **Each harm's test fails before its fix and passes after**, or the finding is declined in
  [F119](README.md#f119) with its reason.
- **`dart analyze` is clean with the strict modes and the two lints, and the whole workflow is green
  on the VM** on the commit handed over.
