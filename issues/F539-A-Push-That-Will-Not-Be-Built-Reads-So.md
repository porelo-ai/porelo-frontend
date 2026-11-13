# F539 — A Push That Will Not Be Built Reads So

```json
{
  "$schema": "issue-1.json",
  "id": "F539",
  "title": "A Push That Will Not Be Built Reads So",
  "state": "Backlog",
  "size": "XS",
  "priority": "Low",
  "rank": 108,
  "blockedBy": [],
  "covers": "A pushed commit whose build verdict is `none`, a push the forge will not build, reads as no build for that push, never as \"Build: none\"."
}
```

**Why this size.** XS: one more case in the verdict's words, the model's comment, and a test.

Found when the machine's gate began to hand in `verdict: none` for a push that will not be built, as a final verdict
beside `success`, `failure` and `cancelled` (2026-11-13).
- `Builds._fromVerdict` (`lib/src/app/builds.dart`) says a verdict it does not know as it comes, so `none` shows as
  "Build: none". That is not wrong, but it does not say that no build will come.
- `Build.verdict` (`lib/src/client/models.dart`) lists the verdicts without `none`.

**What must be true.**
- A build whose verdict is `none` reads "No build for this push", with the look of no verdict (`BuildLook.none`),
  never as running, passed or failed.
- `unknown` still reads as it does: it is not final, and the machine reads it again later.

## Plan

- `lib/src/app/builds.dart`: `'none' => (BuildLook.none, 'No build for this push')` in `_fromVerdict`.
- `lib/src/client/models.dart`: name `none` among the verdicts of `Build.verdict`.
- Red first in the builds' test: a build with verdict `none` reads "No build for this push".
