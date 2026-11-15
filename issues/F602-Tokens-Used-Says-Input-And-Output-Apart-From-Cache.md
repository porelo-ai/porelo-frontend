# F602 — Tokens Used Says Input And Output Apart From Cache

```json
{
  "$schema": "issue-1.json",
  "id": "F602",
  "title": "Tokens Used Says Input And Output Apart From Cache",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 122,
  "blockedBy": [],
  "covers": "A task's Tokens used says the input and output tokens a person can judge, and the cache read and written apart and named, instead of one sum of every kind that reaches 1.5 M within a minute, reasoning counted once and at least shown only for a real gap."
}
```

**Why this size.** S: the tile's one number becomes input and output with cache named apart, from the totals porelo
already sends, reasoning counted once and *at least* only for a real gap; tests of each kind's sum and of
*at least*.

**What must be true.** A person reading *Tokens used* can tell what the task cost them in fresh input and output,
and sees how much was read from or written to the cache without it swelling that number.

## Found

The operator's read-only runs of 15 November (PI68 *In analysis* and *Under estimation*, tasks `pi` and `pi-2` on a
host): *Tokens used: at least 605 k* after less than a minute, *at least 1.5 M* after one minute; the estimation
51 k at its start.

## Plan

- **Today**, read in the code: `UsageTotals.tokens` (`lib/src/client/models.dart`) sums every kind porelo's `Usage`
  reports (`input`, `cacheRead`, `cacheWrite`, `output`, `reasoning`), and `_WorkFacts`
  (`lib/src/ui/attention_view.dart`) shows that sum, *at least* where any kind has requests that reported no
  value. An agent reading its context from the cache on each request makes `cacheRead` the bulk of it.
- **Agreed with Agent Smith** (room, 2026-11-15 15:37Z, read in porelo's `UsageReading` and `UsageSums`):
  - `input` is without the cache in every format: Anthropic's `input_tokens` is so, and porelo subtracts the cached
    part from OpenAI's prompt or input tokens. `cacheRead` and `cacheWrite` are apart.
  - `output` holds the reasoning in the OpenAI formats (codex, pi and omp over openrouter), and `reasoning` is its
    part again; claude never reports `reasoning`, its thinking is inside `output`. So today's sum counts reasoning
    twice for codex, pi and omp.
  - Claude never reports `reasoning`, the OpenAI formats never report `cacheWrite`: `partly` is true for every task,
    so *at least* always shows. A kind a format never reports is no gap; a failed or cut stream nulls every kind.
- **Steps.**
  - `UsageTotals` gives input, output (reasoning within it, never added), cache read and cache written; a total, if
    shown, is input + output + cache read + cache written.
  - The fact reads *12 k in · 3 k out*, with *cache 1.5 M read, 40 k written* beside it in smaller words or its
    tooltip, and *of which N reasoning* where reasoning is reported.
  - *At least* only where `input` or `output` has requests that reported no value, which every format reports; a
    missing `reasoning` or `cacheWrite` is no gap.
- **Red first:** a test of the fact with the live run's shape (cache read far above input), red today on one sum.

## Acceptance

- *Tokens used* says input and output apart from cache, and names the cache. Seen to fail: today's one sum.
- *At least* shows only where input or output had requests without a value; not for a claude task that reported
  both on every request.
- Reasoning is counted once, inside output, for an agent that reports it apart too.

## Built

- **Model:** `UsageTotals` (`lib/src/client/models.dart`) reads each kind apart (`input`, `cacheRead`, `cacheWrite`,
  `output`, `reasoning`) and sums nothing; `partly` is true only where `input` or `output` has requests that
  reported no value. `Usage.read` gives the totals only for an `available` record; the old one sum `tokens` is gone,
  as nothing shows a total.
- **Tile:** `usageInWords` (`lib/src/ui/attention_view.dart`) gives *Tokens used* as *12 k in · 3 k out*, *at least*
  before it only for that gap, and under it in smaller words *of which 1 k reasoning; cache 1.5 M read, 40 k
  written*: reasoning only where reported and above 0, never added to the output; each cache kind only where a request
  reported it. A kind no request reported reads *input not said* / *output not said*, never 0; a record with no kind
  reported keeps *not said*. No other place in the window or the planning screen shows a token count (searched `lib`
  and the pinned porelo-planner screen for usage, token and cache words).
- **Today's daemon and the corrected one alike:** the tests give a format without reasoning or without a cache write
  both as today's machine answers it (missing on every request) and as a machine that counts only a reply's real gap
  (missing 0); both read the same.
- **Red first** (`test/ui/work_page_faults_test.dart`, group *tokens used*, 4 tests): `Expected: '12 k in · 3 k out'
  Actual: 'at least 1.6 M'` (cache read in the sum, *at least* from a reasoning no reply of that format names);
  `Actual: 'at least 616 k'` and `Actual: '616 k'` (reasoning counted twice, inside the output and beside it);
  `Expected: 'at least 12 k in · 3 k out' Actual: 'at least 20 k'`. All four green after the change.
- **Also changed:** the client test reads each kind apart and *partly* from a missing output; the scenario *an
  unfolded row says what its work used* gives input and output (step *the work {w} has used {n} tokens in and {m}
  out*) and reads *184 k in · 2 k out*.
- **Runs:** `dart analyze lib test integration_test tool` No issues found. Whole folders on the final tree, one
  after the other: `test/client` 365 passed, 25 skipped; `test/app` 1707 passed, 5 skipped; `test/features` 985
  passed; `test/ui` 1450 passed. Skipped, each needing what a unit run has not: `live_daemon_test`,
  `live_builds_test`, `live_hand_in_test`, `live_review_test` (a running porelod), `loopback_carrier_test`'s four
  native contenders (Windows sockets only), `published_key_test` (`PORELO_PUBLISHED_KEY=1`).
- **Against the corrected count:** porelo's `4ec6e2f98` (not pushed) says in `UsageCount` and `UsageTotals` what
  this builds on: `missing` counts only a request whose format reports the kind and whose reply left it out, `tokens`
  is null only where no request reported the kind, `output` includes reasoning in every format, and a total is input,
  cache read, cache write and output, never output plus reasoning. Read against that text, no change was needed.
- **Not checked:** the window itself was not run; no live task was read.

## To be checked

- That porelo's `4ec6e2f98` lands on its main with the words above; until then today's contract does not say that
  `output` holds the reasoning, and the window reads it so either way.
- Decided for the window where the corrected count leaves it open: a cache kind's requests without a value never make
  the fact *at least*. With today's machine a format that never reports a cache write is counted missing there, so
  the window cannot tell a gap from it; a reply cut short leaves input and output out too, which says *at least*
  already. With `4ec6e2f98` a cache kind's missing is a real gap; whether the cache line should say *at least* of
  its own is to be read again once it lands.
- Decided for the window: a reasoning count of 0 is not shown, as *of which 0 reasoning* tells nothing; the
  `requests` count is not shown.
