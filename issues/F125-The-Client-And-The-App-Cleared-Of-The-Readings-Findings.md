# F125 — The Client And The App Cleared Of The Reading's Findings

**Status:** Review; published as `0.5.1~snapshot.159`, Build 39082532614 green on every job.
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
  `lib/src/client` and `lib/src/app` documented; no test. The lints that hold it come with
  [F126](README.md#f126).
- **`strict-casts`, `strict-inference` and `strict-raw-types`** on in `analysis_options.yaml`; they
  find nothing in `lib` today.
- **Red first:** each harm's test, named in its commit; the two Windows findings on the Windows job,
  where only it can show them.

## Acceptance

- **Each harm's test fails before its fix and passes after**, or the finding is declined in
  [F119](README.md#f119) with its reason.
- **`dart analyze` is clean with the strict modes, and the whole workflow is green on the VM** on the
  commit handed over.

## Outcome

Each test names its harm and was seen to fail before its fix:

| Finding | Outcome |
|---|---|
| 1, the API path | Joined under the API's path; `forge_test`, every call of a GitHub of its own. |
| 2, a forge's failures | Each said as `ForgeRefused`; `forge_test`, a page that is not JSON, another shape, TLS and HTTP. |
| 3, no time limit | Thirty seconds for a request, connecting and answering; `forge_test` against a silent socket, seen hanging without it. |
| 4, bare casts | Read past another type; `tolerant_readers_test`. |
| 5, the bundle | Said as the machine answering wrongly; `porelo_client_test`. |
| 6, the hand-in | Ends as failed on a file missing or unreadable; `hand_in_test`. |
| 7, the forwards | One raise at a time per homeserver, and one raised after closing taken down; `homeserver_forwards_test`. |
| 8, the WSL key | One primary key or none; `wsl_setup_test`, a second key, and the carried one with its subkey. |
| 9, this computer | Never a WSL distribution or a machine with no socket; `machine_kind_test`, seen red on Linux too. |
| 10, Windows paths | The profile's `.ssh`, and `chmod` only off Windows, through the seam; `project_workspace_on_windows_test`. |
| 11, the stand-in's `Stop` | A count, as the daemon answers; no test, it guards nothing a person meets. |
| 12, two of one name | The second dropped when read; `settings_test`. |
| `frontend.json`'s unknown keys | Kept at each write; `settings_test`. |

The strict analyzer modes are on and find nothing. Every public member of `lib/src/client` and
`lib/src/app` is documented and each doc comment is on its own member; the two documentation lints are
switched on with [F126](README.md#f126), since a lint holds the whole of `lib` and the frame is not yet
documented.
