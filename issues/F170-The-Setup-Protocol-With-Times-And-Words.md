# F170 — The Setup Protocol With Times And Words

**Status:** Review.
**Size:** M - a time on porelo-host's step lines, a step history in the session, and the protocol's and row's words.

**What must be true.** Each step of a server's setup shows when it started, in local time, and how
long it took once ended; a step past its expected time says so in words with how long it has run,
and the overall estimate follows; the protocol shows each step once, in words, without raw JSON.

## Plan

- **Today**, read in the code: `writeHostStep` (`packages/porelo_host/lib/src/step_output.dart`)
  writes each step as JSON to stdout and in words to stderr; `HostSession.protocol` keeps both, so
  every step shows twice and once as JSON (`host_session.dart`, `host_dialog.dart`). `Step` carries
  the expected `seconds` but no time; the session keeps only the current step's arrival and clamps
  the time left to 0 (`machines_page.dart` shows *about 0 s left*).
- **The time, here:** `writeHostStep` stamps every line it writes, its own and those relayed from
  the collection's callback, with `at` (UTC, RFC 3339). `Step.fromLine` reads it when present and
  ignores its absence. No change in the collection.
- **The session:** keeps a step history: per step its start and end `at` (the arrival time where
  `at` is absent). The protocol renders one line per step: local start time, the words, and once
  ended its duration; the stderr lines are kept only when no JSON step came with them (a failure's
  own words).
- **Overrun:** past its expected seconds, the row says *taking longer than the usual 5 min, running
  for 7 min*; the overall line says *about N min left after this step* instead of counting the
  overrun away.
- **Tests, their harm, red first:** the step line written with `at` is read back with it, an
  old line without it still parses, and a malformed `at` is refused as a lost line rather than
  crashing the protocol (a parser crash during a rented run). Words and times' format get no
  test.

## Acceptance

- In the guided walk with the stand-in's slow situation, each step shows its start and duration,
  the slow step says it takes longer, and no JSON line shows.
