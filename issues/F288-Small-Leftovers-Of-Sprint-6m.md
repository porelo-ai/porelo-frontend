# F288 — Small Leftovers Of Sprint 6m

**Status:** Idea.

**What must be true.** Every small edge case found in sprint 6m's last night is kept in one place, for the operator to
place: address forms, quoting, encodings, texts and test gaps. A grave finding never goes here; it gets an issue of
its own.

Gathered from 2026-10-31 on, by the operator's rule of that night. Each point is to be checked against the code before
it is fixed.

## Gathered

1. **An scp path holding `@`:** the join refuses any `@` after the host in every address form. Core's final address
   rule for sprint 6m cuts the scp form where git splits it, and keeps `git@example.org:team@v2:repo.git` as given,
   with no credential. So this interface shows such a project as a refused row of its own. The rest of the join's
   checks agree with Core's rule: a bracketed host must be an IPv6 literal, `%40` is refused, and `host:a@b:c`
   without a user is read as `user:password@host:path`. Only the scp path is to be read as Core reads it.
2. **Linux CI timeout of the terminal close test:** `pty_test` "termination and close wait for the output consumer
   to reach EOF" timed out once on a Linux runner (Build 41235532851). It did not fail here in 5 single runs or in 24
   runs with 8 in parallel, and the close code had not changed. If it recurs, the test's bound is to be looked at
   against a loaded runner.

## Idea

Each point gets a test that goes red with its harm first, when it is placed.
