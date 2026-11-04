# F370 — Start Work In A Project A Machine Carries

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** A machine's page that says "Ready to work on: foo-project" leads to work in that project. In the foo test `scaleway-1` said so, and its *Start work* asked for a repository's address, the way into the *Default* project. The wizard *Start an agent for each repository* could not be reached, and the test stopped there.

## Why, by reading

- **The button looks at no project.** The machine page's `onStartWork` selects the machine and calls `_startInDefault()`. Whatever the machine carries, it goes there, and an address given puts a repository into `default`.
- **The list comes only from the daemon.** `fleet.projects` holds what `backend.projects()` answers for that machine. Nothing in the window brings a project onto it.
- **Before a first start the daemon names only `default`.** So says the window's own comment: "A host lists a project only after the person's first start there; until then its page is the way on". The page was the way on, and its button leads elsewhere. It is a deadlock on the window's side: the list waits for a first start, and the first start waits for the list.
- **The command line differs.** `porelo project list` names a carried project before a first start, as its document says. The daemon's list is Core's to bring in line, and the window then follows by itself.

## The shape

- **The button names its project.** With one project of this person on the machine it reads *Start work in foo-project*, and with several it asks which. *Default* comes only by choosing it.
- **The first start works from the page,** for a project the machine carries and the daemon does not list yet, with the wizard reachable. Whether the window can do this without the list depends on Core's answer, as a start needs a project the daemon knows.
- **If it cannot start yet, it says so,** beside the button, in words saying what is missing. It never falls to asking for an address.

## Acceptance

- On a machine that carries a project of the person, *Start work* never opens the way into *Default* unasked. Seen to fail first.
- From a machine carrying a project with no start yet, a person reaches *Start an agent for each repository…*.
- The way into *Default* remains, by its own name.

## To be checked

- What Core's daemon answers once its list reads what a host carries, and what a first start needs before that.
- The row's way on from *My projects*, which leads to that same page.
