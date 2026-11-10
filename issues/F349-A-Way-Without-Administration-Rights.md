# F349 — A Way Without Administration Rights

```json
{
  "$schema": "issue-1.json",
  "id": "F349",
  "title": "A Way Without Administration Rights",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 9,
  "blockedBy": [],
  "covers": "A person creates the repository and enters each deploy key by hand, so their token needs no Administration."
}
```

**What must be true.** A person who will not or cannot give a token far-reaching rights can do that part by hand, knowingly at more effort: they create the project's repository and enter the deploy key Porelo shows for each repository themselves. Their token then needs no Administration, only reading contents and members.

## How it stands

Read from the code, not run.

- `checkAdministration` in `lib/src/app/forge.dart` refuses a token without Administration on the access repository. Nothing in `lib` calls it, so the refusal the person meets today comes from elsewhere, and that is to be found first.
- The window shows no deploy key. `lib/src/ui/organization_page.dart` only says, in words, that a token is offered for them.

## What it would take here

- A choice, where the token is asked for, between the far-reaching token and doing it by hand, saying the effort.
- Each repository's deploy key shown to copy, and a check that says whether it was entered.

## What it would take on a machine

Size M, as Agent Machines read it, not run. The helper refuses such a token today: `migrate` lists a repository's deploy keys, which needs Administration read, and stops on a 403. Its read key is made in that same step and shown nowhere. It needs the public key shown per repository before any token, and proving the key by a read with it instead of listing.

**What is lost:** the machine cannot see that a hand-entered key is read-only, so a key given write access goes unnoticed, and it cannot remove the key when the project leaves, which stays the person's.

`project open` over a repository that exists, and what else asks Administration, is Core's to say here.
