# F360 — A Count Says What It Counts

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** Two numbers for one word never leave a person wondering which is wrong: where the side bar and a page count different things under the same name, the words say the difference.

## Why

Right after creating a Porelo organization, in the foo test, the side bar said *Machines 1* and *Forges 0*, and the organization page's *Machines* list said 0. Each is right by what it counts:

- **The side bar's *Machines*** counts what this window reaches: the machines it watches and those being prepared, and always this computer. So it is never below 1.
- **The organization page's *Machines*** counts the machines listed in the Porelo organization, here none.
- **The side bar's *Forges*** counts the forges set up in this window's settings. A token put in the vault at a terminal, and creating an organization with it, set none up. So it says 0 for a person who has just used GitHub.

## The shape

- The organization page's list says what it lists, in words such as *Machines in this organization*, and the empty list says that this computer is not one until it is added.
- **Creating a Porelo organization enters its forge under *Forges*,** if that forge is not there yet, without asking for anything again. The token is the access: a person is never asked for the same token twice.

## Acceptance

- With this computer alone and an organization with no machines, a person reads why the two numbers differ, on the page they are on.
- Creating an organization on a forge not yet listed lists it and asks for nothing; the entry then lists that forge's repositories, or says in words why it cannot.
- One token entered once serves the organization, the project's opening and the *Forges* page.

## Two stores for one token today

One person can hold the same token twice. `porelo vault` holds `git.token.<host>`, which Core uses for git and for asking the forge. The system's secret store holds what `porelo-host key set` was given, and the window reads it through `ForgeConnection` for its own questions to the forge: who am I, the repositories, branches, collaborators, and a project's own tools cloning with it. When the vault lacks the token, creating an organization asks for it into the system store and copies it to the vault, so it ends up in both. An entry with no token cannot do without one yet: the entry using the person's identity exists in `ForgeConnection.addIdentity`, and nothing sets its `identityAccess`, so opening it says that access is not available yet.

**What stands against one store:**

- **The vault's value does not reach the window,** by rule: a value is stored on the machine and never passes through this program. The window asking the forge with the vault's token would break that, unless Core asks the forge for it, which means Core answering what the window's `Forge` asks today.
- **The vault shuts when idle.** The system store opens with the login, so *Forges* lists repositories at once; from the vault, each look after it shuts needs its passphrase, or the page says it is shut.
- **A computer with no local Porelo,** only reaching machines, has the system store and no vault of its own.

**The way this issue takes, to be settled when it is analyzed:** the vault as the one store, with the window's forge questions asked through Core, and a shut vault reading as shut, with what is already known still shown.

## To be checked

- Which of the window's forge questions Core can already answer, and what it must add.
- What is left of the system store: for a computer with no local Porelo, and for a person who already holds a token there, which must not be lost.
