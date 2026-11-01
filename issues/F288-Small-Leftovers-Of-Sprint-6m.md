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
3. **A SHA-256 registry:** the registry bundle for a host is built in a bare repository made as SHA-1, so a registry
   whose commits are SHA-256 cannot be brought; it is to be made in the registry's own object format.
4. **`--since` per registry address:** the last revision a host applied is kept per host alone, so after switching to
   another registry sharing an ancestor, the local verification skips history up to it; it is to be kept per registry
   address and host.
5. **Registry bundle folders swept at start:** a crash while sending leaves a `registry-bundle-` folder under the
   app's data that nothing removes; the start sweeps them as it sweeps card copies.
6. **A test of `main.dart`'s composition:** the shell's host access test hands its own host access in, so it stays
   green when `main.dart` composes none; a test of the composed app is to hold it.

## Idea

Each point gets a test that goes red with its harm first, when it is placed.
