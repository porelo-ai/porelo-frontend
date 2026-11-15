# F602 — Tokens Used Says Input And Output Apart From Cache

```json
{
  "$schema": "issue-1.json",
  "id": "F602",
  "title": "Tokens Used Says Input And Output Apart From Cache",
  "state": "Backlog",
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

## To be checked

- Whether Agent Core's `output` should leave reasoning out instead; the window counts it once either way.
