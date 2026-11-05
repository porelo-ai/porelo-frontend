# F385 — New Work Confirms What Was Detected

**Status:** Review.
**Size:** S - one dialog, on the daemon's answer.

**What must be true.** On this computer, *New work* shows the same question as a first start in a terminal: the packages and tools found and the network access it opens, yes or no, with `project.yml` written into the checkout for the person to commit. No leaves the start as it is today and nothing kept, and the next start asks again. On another machine the window uses what the repository holds and says if nothing is there; no plugin runs there. A repository of an organization's project has no question.

## Plan

- Built after the daemon's side, on its interface; the contract is agreed in the room first.

## Acceptance

- Yes writes the file and starts; no starts as today; a later start asks again after no.
- On another machine there is no question, and a repository holding nothing is said.

## Decided while building

- The window had no way to name a checkout, so *New work* on this computer has a step *Use a checkout on this computer*, which picks one with the desktop's folder dialog. Naming an address asks nothing, as an address is no checkout.
- After a no, or an answer with no question, the checkout's `origin` goes into the address field, and the person starts as without one.
- With a host only the checkout names, focus stands on No.
- On another machine the window cannot see what a repository holds without a start, so it says in advance what happens with no `project.yml`, rather than after looking.

## Open questions

## To be checked

- Seen once in the real window on a real daemon and the real Maven plugin: the question, a yes, the file in the checkout, the start form, and a later start asking nothing. The window held the daemon's socket as this computer's. A no, and its `origin`, are held by unit tests.
- *On another machine ... says if nothing is there* is said beforehand as a condition, not found out per repository: Open for the person who reads this to judge.
