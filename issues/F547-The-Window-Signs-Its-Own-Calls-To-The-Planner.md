# F547 — The Window Signs Its Own Calls To The Planner

```json
{
  "$schema": "issue-1.json",
  "id": "F547",
  "title": "The Window Signs Its Own Calls To The Planner",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 109,
  "blockedBy": [],
  "covers": "The window's own calls to porelo-planner, handing in an idea and setting the planner's log level, go through the planning screen's signed call, so a planner that refuses bearer tokens still takes them, and a planner that cannot prove itself is named in the window's log, not trusted."
}
```

**Why this size.** S: two calls in the window move to one exported call of the planning package, plus its pin.

Found when porelo-planner began to sign every call: it refuses a bearer token with 401.

**How it stands.**
- `handIdea` (`lib/src/app/planner_ideas.dart:71`) and `tellPlannerLevel` (`lib/src/app/planner_log_level.dart:42`)
  send `Authorization: Bearer <token>` themselves.
- The window pins `porelo_planning` at `12aefb2`, which has no signed call.

**What must be true.**
- Both calls go through `callPlanner(...)` of `package:porelo_planning`, which signs each request and checks the
  planner's proof.
- A `PlannerNotProven` answer (`proofFailed` or `signatureRefused`) is not taken as the planner's word: the call
  fails, and the window's log names the failure, the port and the planner's log line.
- No call of the window's own sends `Authorization` to the planner any more.
- The window pins `porelo_planning` at the planner's commit that brings the signed call, once it is on GitHub.

## Plan

- A new `callOwnPlanner` (`lib/src/app/planner_call.dart`) wraps the package's `callPlanner`: on `PlannerNotProven` it
  writes one WARN line to the window's log - the failure's name, the port and the package's `logLine`, never the
  token - and rethrows. `handIdea` and `tellPlannerLevel` send through it; their own `HttpClient` and `Authorization`
  header go. Their answers are read from `PlannerAnswer` as before; a refusal of the package (`NoAddress`,
  `PlannerUnreachable`, `TimedOut`, `PlannerNotProven`, ...) becomes `IdeaNotSaved` or `PlannerLevelRefused`, transient
  only where a later try may succeed (`PlannerNotProven` is never transient, as the package states it).
- Tests, all unit level, over a stand-in planner on the loopback address that answers `POST /proof`, checks each
  request's signature with the token and proves each answer, as the planner's access filter does (built with
  `crypto` from the planner's REST forms, not the package's private code), and answers 401 to an unsigned request or
  one with `Authorization`. Red first, against today's bearer calls:
  - `test/app/planner_ideas_test.dart`, *an idea goes signed without the token*: the story comes back, no
    `Authorization` was sent. Harm: a signing planner refuses every idea (401), or the token travels in a header.
  - same file, *a listener that does not prove the token gets no idea*: `IdeaNotSaved`, the stranger received no
    request but the proof, and the window's log names `proofFailed`, the port and the log line. Harm: a private idea
    reaches another account's listener, or the failure is not explained.
  - same file, *a planner that refuses the signed call*: `IdeaNotSaved`, the log names `signatureRefused` and the port.
    Harm: a 401 is taken for the planner's word, and nobody can tell why ideas stay.
  - `test/app/planner_log_level_test.dart`, *the level goes signed without the token*, and *a listener that does not
    prove the token is not told the level*, with the log line. Harm as for an idea: the planner's log never follows the
    person's choice, or the call goes to a stranger unexplained.
  - The other tests of both files keep their stand-in planner, now signing; *the window's planner* group of the
    level's test covers `LocalPlanner` telling a planner found its level through the signed call.
  - Found while building: the package at the new pin signs the board's reads too, so `test/app/planner_test.dart`'s
    stand-in planner signs as well, and `test/client/planner_mock_test.dart` resets the mock through `callPlanner`
    instead of a bearer token.

## How it was built

- `lib/src/app/planner_call.dart` holds `callOwnPlanner`, the one way the window's own calls reach the planner: the
  package's `callPlanner`, with a `PlannerNotProven` written to the window's log as
  `porelo-planner is not trusted (<failure>, port <port>): <logLine>.` and rethrown.
- `handIdea` and `tellPlannerLevel` send through it and no longer open an `HttpClient` or set `Authorization`. A
  listener that does not prove the token fails an idea as not transient (it is not tried again in this window's life)
  and a level as refused, both in the package's words for the person.
- `test/support/signed_planner.dart` is the stand-in planner's side of the signed forms, built with `crypto` from the
  planner's REST description; it answers 401 to a request without a valid signature or with `Authorization`.
- Red first: against the bearer calls, the new and the moved tests of both files failed (401 from the signing
  stand-in, an idea and a level sent to the stranger); a deliberate break of the log line turned the three log tests
  red, and was put back.
- Built against porelo-planner's local commit with the signed call through an untracked `pubspec_overrides.yaml`;
  `pubspec.yaml`'s pin moves to the planner's pushed commit once it is on GitHub. Until a planner with the signed call
  is installed, `test/client/planner_mock_test.dart`, which starts the installed one, fails on its proof here.
