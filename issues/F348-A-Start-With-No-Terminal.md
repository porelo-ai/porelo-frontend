# F348 — A Start With No Terminal

**Status:** Backlog.

**What must be true.** One person starts an organization, a machine and a project from the window alone. No step sends them to a terminal.

The operator's four parts:

1. The forge token reaches Core from the window, for `org create` and `project open`, by `porelo vault put NAME` with the token on standard input. A shut vault is said first.
2. A server's host key is trusted from the window, showing the fingerprint and asking, as the start of work does.
3. *Prepare a machine…* appears for an Organization Admin, a Machine Admin, or a person who holds no organization yet, with no `--roles host-admin`. A person with no such role does not see it.
4. The dialog does not ask the collection's file and digest, which the build knows from `packages/porelo_host/lib/src/collection.dart`. The host key is fetched and its fingerprint shown to confirm. With more than six keys in the agent, only the card's key is offered, so `up` does not stop at sshd's limit.

## How it stands

Read from the code, not run. `Role.hostAdmin` guards the commands of preparing, recovering and taking down a machine, in `lib/src/app/commands.dart`, and `hostAccessFor` in `lib/main.dart` builds nothing without it. `Role.accessAdmin` has no commands. *Choose another organization…* runs `setup --organization ADDRESS --replace`; *create* stands only for a person with no organization.

## What is needed

- From Core: `credentials trust-host --json` without a fingerprint, answering the keys and recording nothing.
- Here: the four parts. `--roles` then decides nothing.

## To be checked

- A fetched host key shown to confirm is trust on first use unless the person compares it with something else. The provider's console is what they would compare with; whether this weakens anything is for the machines' side to say.
- Offering only the card's key, by naming its `.pub` file with `IdentitiesOnly`, against a real agent with more than six keys.
