# F362 — A Click Answers At Once

**Status:** Review.
**Size:** S - a measurement on a real window first; the size of a fix follows from its cause.

**What must be true.** Whatever a click starts, a person sees at once that it arrived: on a row that opens a page, the page with its "Reading…" line. In the foo test, clicking a row under *Projects*, for a moment nothing happens and then the page comes.

## What is measured

- **It is not the wait for a double tap.** Nothing in `lib/src/ui` asks for one, and in a test the row's action runs at the pointer's release, with no time passing.
- **It is not the read of the project, as far as the code goes.** The page is drawn without waiting for it: with the read held open, the first frame already shows the page and its "Reading…" line.
- **The whole window in a test** takes one frame of about 32 ms from the release to that line, a debug build with made-up data on the laptop, one run.
- **So the delay seen is not found.** The test holds no real `porelo`, no real organization and no real display. `porelo --version` takes 0.03 s here, so its start alone does not explain it either; `porelo project show` itself was not timed, and need not delay the page.

An earlier issue, *A Server Dialog Opens At Once*, settled one dialog, not this row, and *A Long Change Shows That It Runs* covers a change, not a page.

- **A real window on a hidden display** takes 65 to 117 ms from the pointer's release to the end of the frame that shows the page, in eight rounds each: a debug build, software drawing, with made-up data and with the real `porelo` answering the read. The real `porelo` changed nothing, as the page does not wait for it. The slowest of about 230 frames took 50 ms. A hidden window is not the person's click: the click was made by the test.
- **The read itself takes 2.1 s here,** `porelo project show` on a project it does not find, three runs of 2.08 to 2.18 s, and `porelo org --json` 2.4 s, against 0.03 s for `porelo --version`. So the page's content comes about two seconds after its first frame, which may be the moment that was seen: the head of the page stands at once, and what the person came for does not.

- **From the press, in a test, nothing waits either.** The measures above start at the release, and a person's click starts at the press. So the pixels of a row were read frame by frame on the test's fake clock, against the row hovered, in a test not kept, as it guards no harm. The largest change of a colour channel out of 255, one run each:

  | Row and pointer | 16 ms | 32 ms | 50 ms | 66 ms | 100 ms | 150 ms | 200 ms |
  |---|---|---|---|---|---|---|---|
  | A row of the organization's projects, mouse | 2 | 4 | 16 | 21 | 26 | 30 | 34 |
  | *Default*'s row in the same list, mouse | 6 | 10 | 16 | 21 | 26 | 30 | 34 |
  | An `ExpandableListRow` alone, mouse over its title's tooltip | 5 | 11 | 18 | 23 | 37 | 87 | 113 |
  | A row of the organization's projects, touch | 0 | 0 | 0 | 0 | 0 | 19 | 31 |

  With a mouse the press effect starts in the first frame after the press, and fades in. On the two rows of the list a held press reaches 26 of 255 at 100 ms, which is faint; whether a person sees that is for a real display to say. Only touch waits, about 100 ms, the framework's press timeout. That is no click, and nothing here changes it.
- **The first frame after the release shows the page,** the list gone: with the "Reading…" line on the organization's row, and *Default*'s own page on its row. That frame took 38 to 92 ms of wall clock across these runs, a debug build in a test also reading pixels, so it is no figure to set beside the real window's.
- **Nothing read on the way runs long by itself.** The row's action only sets state (`_organizationProject`, or `Machines.select`, `selectProject` and `ShellModel.openProject`), `readProject` goes straight to an awaited `porelo`, and those hold no synchronous file or process call. A search of `lib/src/ui` finds no `SelectionArea`, `SelectableRegion`, long press, pan or double tap recognizer. What the listeners of those changes rebuild was not read call by call; the test's frame times above are its measure.
- **So no cause is found in what a test can measure, and nothing is changed.** That leaves the real window, and the two seconds of the read above.

- **A profile build on a hidden display, as a person of the test organization against its real organization**
  (2026-11-10, ten rounds each in two runs, the window at 1280x800, a press held 80 ms on the row of *My projects*
  that opens the project, then let go):

  | From | To | Fastest | Median | Slowest |
  |---|---|---|---|---|
  | the press | the frame with its press effect | 15 ms | 17 ms | 22 ms |
  | the release | the page with its "Reading …" line | 17 ms | 26 ms | 41 ms |
  | the press | the page's content | 2.6 s | 2.9 s | 3.5 s |

  The slowest frame of all rounds took 95 ms, none of them on the way from the press to the page. `porelo project
  show foo-project --json` alone took 2.5 to 2.7 s in three runs, against 0.05 s for `porelo --version`.
- **So the window answers at once, and its content waits for Porelo's read of the project.** The delay seen is the
  two to three seconds in which the page stands with its head and "Reading …", and not what the person came for.

## How it stands

- **The page no longer waits empty for the read.** While the first read of a project runs, its head says what the
  organization's list already holds of it, as its row under *My projects* does: its repositories, its people and the
  person's role, instead of "not read".
- **The organization keeps the last read of each project for the session.** Opened again, the page shows that read at
  once, whole, with the line "Reading *project* again…", and offers no change while it shows it, since a change would
  carry its revision; the new read replaces it when it lands. A reread that fails keeps the last read, says the problem,
  and says that this is the project as last read.
- **Red first**, in `test/ui/organization_project_pages_test.dart`, each seen to fail before the code:
  - *while the first read runs, its head says what the list holds*: `Expected: '2 repositories · 2 people'`,
    `Actual: 'not read'`.
  - *opened again, it shows the last read at once, marked, with no change until the new read*: found 0 widgets with
    key `organization-project-reading-again`, one expected. With the code in and its gate on the member rows broken,
    it found `removeMember/pat` offered on the last read.
  - *a reread that fails keeps the last read, says why, and says it is the last read*: found 0 widgets with key
    `organization-project-as-last-read`, one expected.
- **Measured after the change** on a real window, the same way as before: a profile build on a hidden X display, as
  the test person against its organization, ten clicks on the row of *foo-project*, each held 80 ms. From the release
  to the page's first frame with its head filled from the list: 10 / 27 / 32 ms (min / median / max), before 17 / 26 /
  41 ms. From the second click on, that frame already shows the last read, whole, marked "reading again" (nine of
  nine); the first click shows "Reading foo-project: …" in it. The press effect's frame: 15 / 16 / 27 ms, unchanged.
  The new read still lands 2.4 / 2.5 / 2.7 s after the release, the time of Core's `porelo project show`; showing
  Porelo's own kept read with its age is [F469](README.md#f469), once Core's command keeps its last read and says its
  age.
- **The reading of the code by another model found six things to fix and two to consider; all were taken, three in
  part.** It grew the change from one page to the organization's model and its source as well, beyond the size first
  set. Now every read again of an open page, after a change, *Try again* or *Review the project*, marks what it shows
  as the last read and clears the refusal before; one that fails says "as last read" and offers no change. A last read
  offers no machine's change either, and a refused change waits until the read lands. The last reads and revisions
  are forgotten when the organization is chosen or made anew or none is named; a taken change of a project forgets its
  last read, and a read of the organization without the project, not stale, forgets it too. The head's role before the
  first read says what the list says, a lock, "not a member" and "no role" among it; a last read names no Project Admin
  the organization's list does not. A project read begun while a change is asked is not taken until the change reads
  it again; a project read answering before the organization's first read waits for it, for its members' cards; the
  page given another project or organization reads that one. A refusal of the read is said once, at the top, with its
  *Try again*, and a first read that fails keeps the list's words in the head. Each test was seen red, in
  `test/ui/organization_project_pages_test.dart`, `test/app/organization_test.dart` and
  `test/app/porelo_organization_source_test.dart`, and `test/ui/organization_changes_test.dart` finds the refusal once
  again. **Declined in part:** a request that got no answer is still offered *Try again* on a last read, as it is asked
  again under its own id and revision, never the shown read's; the machine's changes stay offered while a first read
  runs with no last read shown, as they act on the organization's read; a member whose role `project list` has not
  said gets no role in the head before the read, rather than a guessed one.

## What to measure next

Only a real window can show the first two:

- In the operator's window: does the row's press effect show at once, and can a change that faint be seen? If it does, the wait is between the click and the page; if it does not, the window itself is busy or drawing late.
- From the press to the page's first frame on a real display: the windowing system's delivery of the click and the drawing on real hardware stand in no test.
- A window of the published package with a real organization, as the measure above held no organization of its own to read. Not while the operator's test runs, since one computer holds one window of its account.
- Where the 2 s of a read go, in Core's command.

## Acceptance

- From the click to the page's first frame is measured on a real window before and after, and stays below what a person notices.
- A row's press effect shows at once on any click.
