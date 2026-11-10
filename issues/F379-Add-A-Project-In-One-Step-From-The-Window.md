# F379 — Add A Project In One Step From The Window

**Status:** Review.
**Size:** S - one choice in the dialog, and the refusal's words.

**What must be true.** A person naming themselves Project Admin adds a project in the window in one step, as `porelo org project add PROJECT --admin LOGIN --create-repository` does. A person who names someone else keeps the two steps.

## Plan

- The window's *Add a project* takes the same shortcut, in the organization's read and write.
- It is two steps and not atomic: when the forge says no after the project was added, the refusal says the project stands, and what is left to do.

## How it stands

The first point was already true: *Add a project* sends `org project add PROJECT --admin LOGIN --create-repository
--review …` when the person names themselves, with the review choice, and the plain add when they name someone else.
`test/ui/organization_page_test.dart` holds both (*someone naming themselves makes it in one step with the review
choice*, *someone naming another only adds it, as that person makes it*); both went red with the choice inverted in
the dialog (the input lacked `review`, and a null check failed on the other).

The refusal's words are Porelo's: once the project is added, it says the project is added and why its repository is
not, ending in asking again under the same id. The window dropped the id of every answered refusal, so *Try again*
went out under a new one, which Porelo refuses as a project that exists. `Organization.write` now keeps the id of a
one-step add that was refused while the project stands since it was asked, read on the organization read after the
refusal; asked again, Porelo finds the project it added and makes the repository. In
`test/app/organization_test.dart`:

- *refused after the project stood, is asked again under its id and revision, which finishes it* - red first: the second ask
  carried another id (`Expected: 'd19bb40d…' Actual: '4076edaf…'`).
- *refused before the project stood, is a new change on the newer revision when asked again* - passed at once; red with the check made to
  keep every refused one-step add (`Expected: not '5d977905…' Actual: '5d977905…'`), then put back.
- A reading of this change by another model found five faults and one smaller point, all taken. The id was dropped
  when *Try again* was refused once more (the project already stood before that attempt), when the read after the
  refusal failed or kept an older state, and when another read overtook it; it was kept when someone else's change
  moved the organization on, or when the project of that name had its repository or another admin; and a kept id
  outlived the project's repository being made or the project being removed. The id is now kept while the project
  stands under the asked admin without its repository (`opened` not true), for every attempt, and while the read
  cannot tell; never after a `moved-on` refusal; the decision waits for the newest read; and the id is dropped when
  the repository is made or the project removed here, or when a good read shows the project finished or gone. The
  provisional row is marked to replay its id, so *Try again* is never held back to review a project page. Each has a
  test in `test/app/organization_test.dart`, red first against the earlier code or with its part of the fix taken
  out: *refused again on asking again, is still asked under its first id* (`Expected: 'b6bdd8b8…' Actual:
  'c4cc651c…'`); *refused while the read after it failed* and *… answered an old state* (`Expected: 'fc344808…'
  Actual: '5b5f71d4…'`); *refused while another read overtakes the one after it, decides on the newer read*
  (`Expected: 'c7c8083e…' Actual: '96cd40a1…'`); *refused as moved on while the project came to stand* and *refused
  while a project of the name came to stand with another admin* / *with its repository* (`Expected: not '2e320a1c…'
  Actual: '2e320a1c…'`); *refused, then its repository was created here* / *it was removed here* and *refused, then
  read where the project has its repository* / *is gone* (`Expected: not '8d3876b0…' Actual: '8d3876b0…'`); *refused
  with a revision of its own, may be tried again at once* (`Expected: null Actual: 'Review the project before asking
  again.'`). The store in these tests now moves to a new revision while the write is asked, and the base of every
  retry is asserted (`Expected: 'r1' Actual: 'r2'` with a kept id on the newer revision, `Expected: 'r2' Actual:
  'r1'` with a new id on the older). Nothing was declined.

## Acceptance

- Each of the two ends in a test, seen to fail first.
