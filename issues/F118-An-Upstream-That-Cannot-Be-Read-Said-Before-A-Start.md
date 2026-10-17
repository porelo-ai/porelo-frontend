# F118 — An Upstream That Cannot Be Read Said Before A Start

**Status:** Backlog.
**Size:** S - words for four outcomes and one refusal, the fix selectable with a terminal and an
"ask again" beside it, the refusal for both ways a start goes; the stand-in daemon and tests.

**What must be true.** Where the daemon finds before a start that the repository's upstream cannot
be read, the start dialog says why and what fixes it, the way it says an unknown host key today:
a key the upstream refused, a repository not found, a host not reached, or the upstream unreadable
for another cause. Where a mirror is already there and the start goes on, the warning is shown
beside it, not lost.

## Why

`porelo` [B181](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b181) has the
daemon read the upstream with the clone's own credential before a gated start. `CanStart`'s outcome
grows by `UPSTREAM_KEY_REFUSED`, `UPSTREAM_NOT_FOUND`, `UPSTREAM_UNREACHABLE` and
`UPSTREAM_UNREADABLE`, each with a `detail` that says what was tried and ends with the command that
fixes it. `Start` gets the error `UpstreamUnreadable(cause, detail, fix)`, where `cause` is one of
the four without the prefix, or `UNKNOWN_HOST_KEY` for a host whose key changed since it was
trusted. Today an outcome the interface has no words for falls through `Readiness.whatToDo` to the
daemon's `detail`, and `UpstreamUnreadable` reaches the person as the error's bare name.

## Plan

- **`lib/src/client/models.dart`, `Readiness.whatToDo`:** one line per outcome, saying it in words.
  - `UPSTREAM_KEY_REFUSED`: the repository's host refused what this machine offered for it.
  - `UPSTREAM_NOT_FOUND`: the host has no such repository, or none this credential may read.
  - `UPSTREAM_UNREACHABLE`: nothing answered from the repository's host within ten seconds.
  - `UPSTREAM_UNREADABLE`: the repository could not be read.

  The `detail` stays under it, as for every outcome.
- **`lib/src/ui/start_work_view.dart`, the not-ready box:**
  - With these four outcomes, `detail` is a `SelectableText` (`not-ready-detail`), because it ends
    with the command to run.
  - With `UPSTREAM_KEY_REFUSED`, a button `start-fix-in-a-terminal` opens a terminal on the machine
    (`runInATerminal`, as storing a credential does) and asks again when it closes.
  - With all four, an *Ask again* button (`start-ask-again`, `StartWork.askAgain`). An unreachable
    host is often fixed by waiting.
- **`lib/src/app/fleet_backend.dart`, `startRefusalsSaid`:**
  - `UpstreamUnreadable` becomes an exception of its own, `UpstreamUnreadable(cause, detail, fix)`.
    Its words are the cause in a line, the daemon's `detail`, and `fix` as the command to run where
    it is not empty. The line for `UNKNOWN_HOST_KEY` is the one for a key that changed.
  - `startAgain` goes through the same transformer. A listed task started again from its tile today
    shows only the error's name.
- **The mirror's warning:** with a mirror there, `CanStart` answers `READY` without reaching the
  network, and `Start` prints a line before the image is built: `porelo: <detail> Then: '<fix>'.
  This task starts from what the mirror holds, which may be behind, and approved work cannot go
  back until it is fixed.` The final reply has no field for it.
  - **From the dialog:** the line is in the operation's output, which already shows every line.
  - **From a tile started again:** `startWords` (`lib/src/app/outcome_words.dart`) says a start
    that worked without the lines it printed. The mirror's line (`porelo:` … `starts from what the
    mirror holds`) joins the words said, so the warning is not lost behind "was started".
- **`lib/src/mock/machine.dart`:** the stand-in daemon answers the four outcomes for a repository
  marked unreadable, and `Start` refuses it with `UpstreamUnreadable`.
- **Red first:**
  - `test/app/start_refusal_test.dart`: `UpstreamUnreadable` passed as it came. Today its words are
    only the error's name.
  - `test/ui/start_work_test.dart`: an `UPSTREAM_KEY_REFUSED` answer. Today the dialog has neither
    the button nor the selectable detail.

## What a probe costs the dialog

The dialog asks `CanStart` again two seconds after each change. Porelo reads the upstream only once
everything else is ready, and only where there is no mirror yet. A read that succeeds counts for 30
seconds per account, repository and address, so it costs at most one round trip in 30 seconds. A
refusal is never kept, so asking again after a fix sees the fix. A read takes at most about ten
seconds, and an answer to an older question is dropped (`_asked`), as now.

## Acceptance

- **Each of the four outcomes is said in words, with the daemon's fix selectable beneath.** A
  refused key also offers a terminal on the machine, and all four offer to ask again. Seen to fail:
  the start dialog's test with `UPSTREAM_KEY_REFUSED`.
- **A start refused with `UpstreamUnreadable` says the cause, what was tried and the command,**
  both from the dialog and from a tile started again. Seen to fail: the refusal test.
- **A start that goes on from the mirror shows Porelo's warning,** in the start's output and in the
  words of a tile started again. Seen to fail: `test/app/start_again_words_test.dart` with the
  warning printed before a start that worked.
