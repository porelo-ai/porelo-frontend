# F457 — Needs You Names The One Thing To Do

```json
{
  "$schema": "issue-1.json",
  "id": "F457",
  "title": "Needs You Names The One Thing To Do",
  "state": "Implementing",
  "size": "L",
  "priority": "Medium",
  "rank": 2,
  "blockedBy": [],
  "covers": "*Needs you* items name one action, close with their cause, can be marked seen, embed no task tile; nothing waits at the gate in class online; a done task shown done; the commit's makers shown."
}
```

**Why this size.** grown from M at its plan reading: *Needs you* split into one row per cause across the attention model,
the task model and four views; a seen mark kept safely; a project in class `online` said alike on every screen; built
in three parts.

**What must be true.** Each item under *Needs you* says what the person must do and offers that one action; it goes
away when its cause ends; an item that only informs can be marked seen; and nothing there contradicts what the gate
or the forge says.
- An item names its action: "pull request 1 waits for your approval and merge", opening the pull request on the
  host's forge; it does not embed the task's tile, which stays in *Work*.
- It closes itself when its cause ends (merged or closed); one that only informs has *Seen*, and stays gone.
- A project in class `online`, whose pushes pass the gate at once, shows no "its commit waits at the gate" and no
  item for it.
- A task that said it is done and stopped is shown as done in *Work* and under *Needs you*, not as running.
- The commit's makers - author, committer, trailers - are seen on the item that asks for a review.

## Plan

Read in today's code at its plan reading; the parts are built in this order, each with its own red tests.

1. **One row per cause, one action each** (`lib/src/app/attention.dart`, `lib/src/ui/attention_view.dart`).
   `Attention._tilesOf` makes one tile per task today, so a question hides an ended agent, and an ended agent a push at
   the gate. Each open prompt, each unseen ended agent and each push at the gate becomes a row of its own, with its own
   id in `_keepOutcomes`. A row names its action and offers it; a decision keeps both its answers (allow and refuse,
   *Keep it blocked*, *Rework…*) and a held message is still read before it is decided. The task's tile is no longer
   embedded: what only it said and a person must still see - `unenforced` clearance, asked before, a prompt's deadline,
   files changed that never reached the gate (`ended.unpushed`), a prompt with no task - moves onto the cause's row.
2. **Seen, only for what informs** (`attention.dart`, the settings it keeps today: `seenSilent`, `endedPutAway`,
   `ranOut`). *Seen* is offered only where nothing is owed: a silent task, an ended agent with nothing unpushed, ran
   out, missed, set aside, a story's work ended, a failed operation. A mark's key holds the occurrence (its time or
   count), never an error's text, so a later failure of the same task shows again. Marks are pruned only once the
   settings are loaded and the source that names the cause is read whole (a machine connected with its list read, a
   board live and complete); a stream-only cause keeps its mark for a bounded time.
3. **A project in class `online`, said alike everywhere** (`Attention.demandOf`, `Task.atTheGate` in
   `lib/src/client/models.dart`, `TaskTile`, `WorkRow`, `_WorkFacts`, `ProjectsPage`, `MachineTree`). What a real host
   answers for `waiting` and `pending` of an `online` project is measured first; an `online` task or project derives
   no waiting-at-the-gate words or row on any screen, while a push the daemon's `Pending` still lists is shown, never
   hidden; an unread or empty class is not taken for `online`.
4. **Blocked, not built here:** the pull request on a host's forge (its approval and merge as the one action, the row
   closing when it merges or closes) needs a call of `org.fuin.porelo.Tasks1` that reports a host forge's open pull
   requests, their makers and their end; it is in `doc/Contract-Gaps.md`. The window never asks a forge over HTTP,
   and opens a pull request only at the address it builds from the host's forge forward, a repository path and a
   positive number. A done task's own state waits for the backend's; until then `Demand` keeps an ended or unknown
   activity apart from running, in the activity's own words, and a running count leaves it out.
- **The commit's makers** stand on a push's row as the gate's `Pending` reports them, run through the trailer check,
  said as the head commit's alone unless the push's commits were read, and "not reported" where absent.

## How it stands

Part 4 first: the pull request on a host's forge and the done task's own state, freed by Porelo's
`PullRequests`/`WatchPullRequests` and the task state `done` (2026-11-10).

- Each part gets one reading of its own new code by another model, its findings fixed once, and no second reading (the coordinator, 2026-11-10).
- **Part 2's reading fixed** (2026-11-10), each finding checked against the code first:
  - Taken, red first in `test/app/seen_marks_test.dart`:
    - Must 1: a seen question its machine says again came back as unseen once its mark's week was over (red:
      `Expected: empty Actual: [Instance of 'RanOutQuestion']`, past the week); an occurrence already seen is now
      forgotten as its machine says it again.
    - Must 6, its first half: work running out on the same question again filed one row per time (red: three ids
      where one was expected); a later unseen occurrence now takes the earlier one's place.
    - Must 5: a mark with no time, seen, hid the work's next end for the window's life (red: `Expected: an object
      with length of <1> Actual: WhereIterable<Tile>:[]`, it ended again), and an older build's mark of an end with
      no time hid such ends (red: the same line); this window's own marks now go as the stored ones do, and an end
      with no time is seen only by this window's mark.
    - Must 8: with no machines stored, the stored machines were never read whole, so a seen set-aside notice was
      never dropped (red: `Expected: true Actual: <false>`, `machinesRead`).
  - Taken, red first in `test/app/planning_attention_test.dart`: Must 2, a story's seen end was dropped when another
    story was seen while its work could not be read, and came back (red: `Expected: empty Actual: ['story ended
    builder/demo/story']`); a board is read whole only once every story's work is current.
  - Taken, red first in `test/ui/needs_you_causes_test.dart`: Must 7. The plan's point 2 and this issue name *Seen*
    as the word of whatever only informs, ran out among them, and [F353](README.md#f353)'s *Got it* came before it, so *Got it* became
    *Seen*; a failed operation, named by the plan too, gets *Seen* beside *Open what it printed* (red: `Expected:
    exactly one matching candidate Actual: _DescendantWidgetFinder:<Found 0 widgets with text "Seen" ...`).
  - Must 9: its first and third gaps are the tests above; its second goes with Must 3.
  - May 1 taken without a test: the pruning of silence marks runs on the marks as they are when it runs and not
    after the window is closed, so a mark set in between is kept; the race cannot be placed by a test without
    reaching into the timing.
  - Declined: Must 3 and Must 4, marks set or questions run out before the settings are read: the window reads its
    settings before it builds what needs a person (`_compose` in `lib/main.dart`), so neither can happen there; the
    window-only marks are the guard. Must 5's empty `at` of a question that ran out: the machine stamps every
    settled question with its time. Must 6's second half, marks of forgotten machines: bounded by what was marked
    before the machine was forgotten, as before this part, and nothing grows on its own. May 2, the settings'
    change running the rows again within a pass: the inner pass works from the same state, so no row is wrong, only
    worked out twice.
- **Part 1's reading fixed** (2026-11-10), each finding checked against the code first:
  - Taken, red first in `test/app/attention_causes_test.dart`: a question that ran out no longer also stands under
    *Recently resolved* (red: `Expected: not contains a string starting with 'question '`); a wait that becomes its
    question is not said resolved (red: `Expected: not contains a string starting with 'waits '`), and a question
    answered while the list still says the task waits asks nothing again until the list says so (red: the same line,
    on the open rows). The waits row stands down while an answer of that task is newer than its wait.
  - Taken, red first in `test/ui/needs_you_causes_test.dart`: the steps about a tile read its row under *Needs you*
    when that is the page shown, never leaving for *Work* (red: `Expected: throws <Instance of 'TestFailure'> Actual:
    <Instance of 'Future<void>'> Which: emitted <null>`, the step passed on *Work*'s tile).
  - Taken without a test, as they only read wrong and harm nothing: a row's title says the task's caption, and an
    unfolded row lets the name be selected where it is not the title; a question whose task is not listed yet unfolds
    instead of opening *Work*; an unfolded row says an ended agent's lines only on its own end row, the wait once, and
    no "came before the list" on a resolved question; the countdown reads `causes`, `needing`'s doc is current, the
    dead count of more questions is gone and questions of one time are ordered by identity.
  - Declined: cause-specific titles for resolved ended and gate rows; the unfolded row already says what came out,
    and the folded header names the task, so the worth is low.
- **Part 2 built** (2026-11-10), part 3 not yet:
  - *Seen* stands only where nothing is owed: a silent machine, an ended agent with nothing outside the gate, a
    question that ran out, dropped questions, the notice of machines set aside (new) and a story's ended work (new,
    beside the planning package's row; the package itself is unchanged). A question, a push at the gate, a pull
    request and a stopped reading offer none, and an end that left files outside the gate neither offers *Seen* nor
    goes when its log is read or its work opened; a mark an older build kept for such an end hides nothing.
  - Each mark holds its occurrence, never an error's words: an end by its time (or its state's start), its outcome
    and its count of files; a question that ran out by its identity and the time it ran out
    (`<machine>/<task>/<key> at <time>`); a story's end by its entry and the time its work ended; the set-aside
    notice by the machines it names; a silent machine by its name, the mark going the moment it answers, so it is
    the silence since its last answer; dropped questions by their count, which a new drop raises. An end or a story
    end without any time is seen only for the life of the window, so it cannot hide the next.
  - Old marks: a seen question that ran out kept without a time names no occurrence, so it hides none and is dropped
    at the next pruning; old end marks already held their time.
  - Pruning: nothing is pruned or written before the settings are read (`Settings.loaded`); until then a mark lives
    in the window only. An end's mark goes once its machine answered and read its list without it; a story's once
    its board is live and complete and says that end no longer; the set-aside mark once the stored machines were
    read and name other ones. Questions that ran out come only from the `Prompts` stream, which never says one is
    gone: a seen one is kept 7 days (`Attention.ranOutSeenKeptFor`), long enough to outlast a computer asleep over a
    weekend when the machine sends the same occurrence again on a new connection, and at most 50.
  - Seen red first: `test/app/seen_marks_test.dart` (a question running out again is said again; an older build's
    mark hides nothing; a seen mark kept a week, then dropped; an end with files outside the gate cannot be put away
    nor hidden by a mark; a mark set before the settings were read keeps the stored ones), a story's end in
    `test/app/planning_attention_test.dart`, the set-aside notice in `test/app/host_card_tunnel_test.dart`, and no
    *Seen* on an end with files outside the gate, a question or a push in `test/ui/needs_you_causes_test.dart`.
    `needs_a_person.feature`'s scenario on files outside the gate changed by design: it now finds no *Seen* and the
    count unchanged after the log is read, where it put the end away before. The test of an end put away on a slow
    machine in `test/ui/work_page_faults_test.dart`, and the feature tests' window, now read their settings first, as
    the window does.
- **Part 1 built** (2026-11-10):
  - `Attention.causes` makes one row per cause: each open question by its own identity
    (`question <machine>/<task>/<key>`), a wait the task says it is in with nothing asked (`waits`), an end nobody has
    seen (`ended`) and a push at the gate (`gate`), so a question no longer hides an ended agent and an ended agent no
    longer hides a push. What came out of each question goes under *Recently resolved* under that question's id, also
    when its work holds a push; the *Got it* on a kept row is gone with the row.
  - Each row offers its cause's action: a question *Keep it blocked* and *Let it through* (and its terminal), an end
    *Read its log* and *Put it away*, a push *Review at the gate*; reviewing the push no longer puts the end away. A
    held message is still decided only in its dialog, once its text was read. *Rework…* belongs to a stopped
    reading's row, drawn by the planning package with *Review anyway* and *One more round*, and is unchanged.
  - No task tile, menu or tile button stands in a row; the tile widget is gone, and *Work* keeps the task's own. What
    only the tile said is on the cause's row when opened: `unenforced` clearance, asked before, a question's deadline,
    files changed that never reached the gate (also on the folded row), and a question whose work the machine does not
    list yet. An ended row stands under *Also needs you*, its push under *Reviews*.
  - Seen red first: `test/ui/needs_you_causes_test.dart` (two rows for a question and an end, two for an end and a
    push, both answers, every fact on its row, no tile inside a row; the held message test was seen red by letting the
    dialog decide unread). Changed with the shape: three tests in `test/ui/work_page_faults_test.dart`, one in
    `test/ui/done_task_test.dart`, one check in `test/ui/needs_you_pull_request_test.dart`, and the steps behind
    `needs_a_person.feature`, whose wording is unchanged.
- **Part 4 built** (2026-11-10):
  - The client reads Porelo's `PullRequests` and `WatchPullRequests` (`HostPullRequest`, `PullRequestsSeen`), with
    the two refusals typed; `lib/src/app/host_pull_requests.dart` watches each project a machine carries and keeps
    its rows: a row closes only when the watch lists it ended; an error or a lost connection marks the rows stale and
    asks again after 30 seconds; an older daemon shows nothing.
  - *Needs you* has a row per open pull request in *Reviews*, "Pull request N of <repository> waits for your approval
    and merge", whose one action opens it on the host's forge (the forge forward raised as *Open its forge* does,
    the address from the host's forge, the repository's copy and a positive number); the head commit's makers go
    through the gate's own card and trailer check, "not reported by the machine" where absent; no task tile. A
    refusal is one row per project in words, a missing token's store command shown to copy, never run.
  - A task in state `done` is shown done in *Work* and on its *Needs you* row, never running; the running counts of
    *Work* and of a repository's row leave it out (`Task.runningWork`). It makes no *Needs you* row on its own: it
    waits on nobody.
  - The mock's situation `pull-request` has one pull request that ends as merged (key `m`) and a done task.
  - Each test was seen red first (`test/client/host_pull_requests_test.dart`, `test/app/host_pull_requests_test.dart`,
    `test/ui/needs_you_pull_request_test.dart`, `test/ui/done_task_test.dart`,
    `test/client/mock_pull_requests_test.dart`).
  - Limits: the trailer check on a pull request always says it cannot be checked here, since Porelo reports no whole
    commit message; the address is built from the repository's upstream name, so a row whose repository has none
    shows but cannot be opened (a new gap in `doc/Contract-Gaps.md`); the side tree's counts start from the daemon's
    own `running` and leave out a done task whose container is up.
  - Not run live: the rented host runs a Porelo from before the pull request calls.
- A second reading of part 4 came back with eight must-fix and four may-fix findings; one fix round took them as
  follows, each test seen red first.
  - Taken: the rail's and the machine card's running counts, a project's and a repository's running counts, and a
    done task whose terminal ended now leave a done task out or call it done; a pull request ends only when its
    project's host says so, and a project no longer carried or listed keeps its rows as possibly out of date instead
    of resolving them, while a resolved row says *Merged*, *Closed* or *No longer open on the forge*; a watch that
    ends without a word or loses its own connection is said and asked again; a store command is offered only when
    every word is text free of control and line separators, the words name "the command below" only when there is
    one, and the row's state follows the refusal's type; trailers holding anything but text read as not reported;
    the tests now reach the rail's count, a quoted command, and the forge forward raised before a pull request
    opens.
  - Taken from the may-fix: an upstream that names no repository (a bare host, a bare word) gives no address;
    *Open the pull request* waits for the connection to its host and says a failed forward in a snack bar; refreshing
    a machine or opening *Needs you* asks a refused or ended watch again at once.
  - Declined: counting the orphaned project's tasks by running work, since its count is the containers up like the
    daemon's and the project's count now leaves done tasks out once, so changing both would leave them out twice;
    reading the trailers as the whole truth, since the interface says a field it leaves out means the check cannot
    be made, and the gate shares that rule.

## Acceptance

- The mock with an `online` project: no waiting item; with a pull request waiting: one item, one action, gone after
  the merge; an informing item marked seen stays gone after a restart. Seen to fail: the task tile inside an item.
