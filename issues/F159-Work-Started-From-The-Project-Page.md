# F159 — Work Started From The Project Page

**Status:** Accepted.

**What must be true.** The project page offers a visible start button on each repository row and
one for the project as a whole, not only an item inside each repository row's `⋮` menu. When the
start form is opened from a repository row's start action, the chosen repository is shown as text
with a *Change* action beside it instead of an open *Which repository* dropdown.

## Why

On the project page, starting work is hidden in each repository row's `⋮` menu (*Start work in
\<repository\>*) and missing beside the project title, and opening the start form from a repository
row still shows *Which repository* as an open dropdown.

## Acceptance

- The project page shows a visible start button for the project and one on each repository row;
  opening the start form from a repository row shows that repository as plain text with *Change*
  beside it.
- Seen to fail: starting from a repository row uses that repository unless the person clicks
  *Change* and picks another.

## To be checked

- How the project-wide start button connects to starting work in one or more repositories of the
  project.
