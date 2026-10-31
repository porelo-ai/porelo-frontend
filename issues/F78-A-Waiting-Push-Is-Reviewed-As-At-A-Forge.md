# F78 — A Waiting Push Is Reviewed As At A Forge

**Status:** Analyzed.
**Size:** S - one view (`lib/src/ui/gate_view.dart`) and the gate's model reading two fields the daemon adds; no
diff rendering, no new package, no state kept on disk.

**What must be true.** A person decides a waiting push in the interface without an IDE: its page shows the push's
source level (`E0`, `E1`, `I1`, `A`) and highest risk class (`C0`–`C3`), the files in risk order with each file's
class, and one decision, *Let it through…* or *Turn it away*. The code itself is read in IntelliJ, from the fetch line
on the same page.

## Why

The review shows git's diff, which is correct but made for a machine, and a reviewer reads code better in an IDE. The
interface keeps what a decision needs: how far the push is trusted, how risky it is, and which files make it so,
highest risk first.

## Plan

Read in today's code: `Gate` (`lib/src/app/gate.dart`) holds the push's `diff`, `ranked` and `asked`; `ReviewView`
(`lib/src/ui/gate_view.dart`) draws one list, a `_RankedFile` or `_File` per file opening to its `_Line`s, with
`_OwnClone` above it and *Copy the diff*, *Drop the request* and *Forward it upstream…* in `_Decision`. `PendingPush`
and `ReviewFile` (`lib/src/client/models.dart`) carry the rank (`DANGEROUS`, `ORDINARY`, `GENERATED`,
`REFORMATTING`) but no source level and no `C0`–`C3` class.

- **Waits for the contract:** the daemon answers the waiting push's source level and highest risk class on
  `PendingPush`, and each file's class on `ReviewFile` in the ranked list, in its own order. `doc/Backend-API.md`
  and `doc/Contract-Gaps.md` take them first; `MockMachine` (`lib/src/mock/machine.dart`) and `FakeBackend`
  (`test/fakes/fake_backend.dart`) serve them. The let-through and turn-away calls are the gate's existing ones.
- **Red first:** a scenario in `test/features/work_handover.feature` that opens a waiting push with one file of each
  class and finds the header's level and class and the list in the machine's order with a class per file.
- **Header.** `ReviewView` shows above the list: project, repository, task, the waiting commit and its base, the
  source level and the highest risk class. A level or class the daemon did not report reads "not reported", and a file
  without a class shows `—`, never `C0`.
- **One list.** `_RankedFile` keeps its row (class, path, the machine's reason, `+`/`−` counts) and no longer opens to
  lines; `_File` and `_Line` go, with the diff drawn in the interface. The note that the order is the machine's and
  judges no file safe stays.
- **Fetch line.** `_OwnClone` stays, worded "Read it in your own clone, in IntelliJ", with its *Copy*.
- **Decision.** `_Decision` holds *Turn it away* (today *Drop the request*) and *Let it through…* (today *Forward it
  upstream…*); *Copy the diff* goes. The branch dialog names the commit it lets through. When the push has a `C3`
  file, it asks a second time and names those files. When a check is not complete, it names each such check and lets
  the push through on a yes; it is never refused for that. The gate's existing second-person rule is not replaced.
- **States.** While the push is read, the list says so and the decision is listed as unable to run with that reason.
  A refusal (for example the push moved to another commit) shows in Porelo's words in `GateProblem`, and the decision
  cannot run until the page is read again. While deciding, nothing changes until the daemon answers. A lost connection
  keeps the last page with the time it was read, and the decision cannot run.
- **Bidi and control characters.** File paths, commit subjects and branch names show Unicode bidi overrides
  (`U+202A`–`U+202E`, `U+2066`–`U+2069`) and control characters (`< 0x20` except `\t` and `\n`, plus `0x7F`–`0x9F`)
  as visible badges.

## What it drops

- Two panes, side-by-side or inline diffs, syntax colours and their package, unchanged lines expandable to the whole
  file, commit-bound read ticks kept on disk, and *Approve* waiting on every `C3` file being ticked: gone from the
  interface. Reading the code moves to IntelliJ through the fetch line; the IntelliJ plugin's own review
  (`porelo-intellij`) carries diffs and comments.
- *Copy the diff* and its scenario "the diff leaves the interface in one action, for reading somewhere else": nowhere;
  the fetch line is enough.

## Acceptance

- The push's page shows the source level and highest risk class above the list, and every file with its class in the
  machine's order. Seen to fail: a scenario in `test/features/work_handover.feature` where the order differs or a
  level or class is missing.
- A level or class the daemon did not report reads "not reported" or `—`, never `C0`. Seen to fail: a scenario with an
  older daemon's answer where a missing class reads as `C0`.
- *Let it through…* on a push with a `C3` file asks a second time and names those files; with a check not complete it
  names that check and lets it through on a yes. Seen to fail: a scenario where a `C3` push goes through on one
  confirmation, or a check not complete refuses the decision.
- A refused decision shows in Porelo's words and changes nothing until the daemon answers. Seen to fail: a scenario
  where the push leaves the list before the daemon's answer.
- The page draws no diff and offers no *Copy the diff*; the fetch line stays. Seen to fail: the scenario "a waiting
  push can be fetched into the person's own clone" goes red, or a diff line is found on the page.
- A file path or commit subject with `U+202E` shows it as a badge. Seen to fail: a widget test with `U+202E` in a path.

## To be checked

- The field names the daemon gives the source level and the classes on `PendingPush` and `ReviewFile`.
