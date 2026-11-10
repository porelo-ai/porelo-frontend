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

- *refused after the project stood, is asked again under its id, which finishes it* - red first: the second ask
  carried another id (`Expected: 'd19bb40d…' Actual: '4076edaf…'`).
- *refused before the project stood, is a new change when asked again* - passed at once; red with the check made to
  keep every refused one-step add (`Expected: not '5d977905…' Actual: '5d977905…'`), then put back.

## Acceptance

- Each of the two ends in a test, seen to fail first.
