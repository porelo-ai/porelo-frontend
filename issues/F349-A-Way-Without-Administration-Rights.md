# F349 — A Way Without Administration Rights

**Status:** Idea.

**What must be true.** A person who will not or cannot give a token far-reaching rights can do that part by hand, knowingly at more effort: they create the project's repository and enter the deploy key Porelo shows for each repository themselves. Their token then needs no Administration, only reading contents and members.

## How it stands

Read from the code, not run.

- `checkAdministration` in `lib/src/app/forge.dart` refuses a token without Administration on the access repository. Nothing in `lib` calls it, so the refusal the person meets today comes from elsewhere, and that is to be found first.
- The window shows no deploy key. `lib/src/ui/organization_page.dart` only says, in words, that a token is offered for them.

## What it would take here

- A choice, where the token is asked for, between the far-reaching token and doing it by hand, saying the effort.
- Each repository's deploy key shown to copy, and a check that says whether it was entered.

The other parts are for the helper on the machine and for `project open`, which their owners say here when they have read them.
