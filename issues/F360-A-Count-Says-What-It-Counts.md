# F360 — A Count Says What It Counts

**Status:** Review.
**Size:** M - the side bar's names and counts, and a forge entered on creating; the one store is apart.

**What must be true.** Two numbers for one word never leave a person wondering which is wrong: where the side bar and a page count different things under the same name, the words say the difference.

**Decided:** this issue builds the names, the counts and the forge's entry. One store for one token is apart and later, so "One token entered once" below waits for that; a machine's token now comes from the system's store, by another issue's decision.

## Why

Right after creating a Porelo organization, in the foo test, the side bar said *Machines 1* and *Forges 0*, and the organization page's *Machines* list said 0. Each is right by what it counts:

- **The side bar's *Machines*** counts what this window reaches: the machines it watches and those being prepared, and always this computer. So it is never below 1.
- **The organization page's *Machines*** counts the machines listed in the Porelo organization, here none.
- **The side bar's *Forges*** counts the forges set up in this window's settings. A token put in the vault at a terminal, and creating an organization with it, set none up. So it says 0 for a person who has just used GitHub.

## The shape

- **The side bar reads *My projects*, *My machines* and *My forges*,** in sentence case, and those pages' own titles with it. The organization page's lists stay *Projects* and *Machines*, as they show the whole organization. That names the difference between the two numbers.
- **Creating a Porelo organization enters its forge under *Forges*,** if that forge is not there yet, without asking for anything again. The token is the access: a person is never asked for the same token twice.

**What each counts, read in the code:**

| Name | Counts |
|---|---|
| *My machines* | The machines this window watches, those being prepared, and always this computer. |
| *My forges* | The forges set up in this window's settings, `ForgeConnection.entries`. **Its page lists more:** `allEntries`, which holds the machines' own forges too, so the number can be below the page's rows. The number becomes the page's. |
| *My projects* | Its page lists the projects the person holds a role in, so it already means what the word says. **Its number does not:** with an organization read, `projectsInRail` counts all of the organization's projects, though its comment says it counts what the page lists. The number becomes the page's. With no organization read, both are those on the machines this window reaches. |
| The organization page's *Projects*, *Machines* | The whole organization's. |

## Acceptance

- The side bar and those three pages say *My projects*, *My machines* and *My forges*; the organization page's lists keep their names; each count equals the rows of its page, a person with a role in one of two projects reading 1. Seen to fail first.
- Creating an organization on a forge not yet listed lists it and asks for nothing; the entry then lists that forge's repositories, or says in words why it cannot.
- One token entered once serves the organization, the project's opening and the *Forges* page.

## Two stores for one token today

One person can hold the same token twice. `porelo vault` holds `git.token.<host>`, which Core uses for git and for asking the forge. The system's secret store holds what `porelo-host key set` was given, and the window reads it through `ForgeConnection` for its own questions to the forge: who am I, the repositories, branches, collaborators, and a project's own tools cloning with it. When the vault lacks the token, creating an organization asks for it into the system store and copies it to the vault, so it ends up in both. An entry with no token cannot do without one yet: the entry using the person's identity exists in `ForgeConnection.addIdentity`, and nothing sets its `identityAccess`, so opening it says that access is not available yet.

**What stands against one store:**

- **The vault's value does not reach the window,** by rule: a value is stored on the machine and never passes through this program. The window asking the forge with the vault's token would break that, unless Core asks the forge for it, which means Core answering what the window's `Forge` asks today.
- **The vault shuts when idle.** The system store opens with the login, so *Forges* lists repositories at once; from the vault, each look after it shuts needs its passphrase, or the page says it is shut.
- **A computer with no local Porelo,** only reaching machines, has the system store and no vault of its own.

**The way this issue takes, to be settled when it is analyzed:** the vault as the one store, with the window's forge questions asked through Core, and a shut vault reading as shut, with what is already known still shown.

## Decided while building

- **The entry names the forge by the host of the organization's repository,** and is a GitHub entry as *Add a forge* makes by default. Where no token is kept in this computer's store, it stands and says so; a token only in the vault is that case.
- **A section of one machine's or one project's page keeps its short title,** such as *Projects* on a machine's page, as it counts neither of the side bar's numbers.

- **The number is the page's rows, with no filter counted:** a filter narrows what is shown, and the head of a list keeps saying how many there are.
- **"All projects on your machines" counts what it lists** while it is shown, and the number goes back with the way back.
- **A forge open in the window stays open** when an organization is created on another.

## To be checked

- Words elsewhere that name these places, such as "under Projects", the help, the pictures and their alt text.
- Which of the window's forge questions Core can already answer, and what it must add.
- What is left of the system store: for a computer with no local Porelo, and for a person who already holds a token there, which must not be lost.
