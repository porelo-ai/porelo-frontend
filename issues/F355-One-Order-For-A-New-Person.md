# F355 — One Order For A New Person

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** A new person is given one clear order in the window: do A, then B, then C. Each step shows its state, read and checked before the last step, so *Create it* is reached only when it can work, and a refused step says what to do next in plain words. Today each need is met only as a refusal, in the order the code happens to check.

## The shape

**The order at the start, for creating an organization:**

1. The key is loaded and the card is made.
2. An empty repository exists on the forge.
3. A forge token exists, with its rights named and why they are needed.
4. The token is in the vault.
5. *Create it*.

Each step shows whether it is done. *Create it* can be pressed when every step before it holds: a key the agent serves, a card, a token the forge accepts with the rights needed, and a repository that is empty.

The order goes on past the organization: the project, its repositories, a host, agents. Those steps are added as the foo test reaches them.

**The token's step says why a token is needed at all:** the forge is asked who owns the organization, only a token can ask that, and an ssh key does not replace it.

## What can be read today, and what cannot

| Step's check | Today |
|---|---|
| The agent serves a key | Exists. `porelo identity keys` lists them, and the window reads it. |
| A card, and its key held | Exists. The window reads the card, and whether the agent holds, does not hold or is absent. |
| The token is in the vault | Exists while the vault is open: the window reads an entry `git.token.<host>` and its length, never its value. An entry in `credentials.yml` naming another place is read too. |
| The forge accepts the token | In part. `porelo credentials check URL` reads the address with it, and the window has the call but does not use it. The window's own question to the forge, who am I, uses the token in the system's store, not the vault's. |
| The token has the rights needed | Nothing. Core must add it, since the vault's token never reaches the window. |
| The repository is empty | Nothing that can be asked beforehand. Core reads it only inside `porelo org create`; `credentials check` names a missing repository, not a filled one. Core must add it. |

**What Core is asked for:** one question that only reads, given the address, answering each of these apart: repository reached, repository empty, token accepted, the rights it holds or lacks, and the person's standing on the forge. It fills nothing. Why a failed creation reads as it does is a separate matter on Core's side and stays there; this asks beforehand.

## Acceptance

- A new person with nothing set up sees every step and its state before doing any of them, and no step's need first appears as a refusal.
- *Create it* cannot be pressed with no key served, no card, no token, a token the forge refuses, a token lacking a right, or a filled repository, each against a stand-in forge and seen to fail first.
- No token value reaches a widget or a line of text.

## To be checked

- With Core: the rights a token needs for creating an organization, opening a project and adding read keys. Classic `repo` and `read:org` are what the first run used.
- A fine-grained token: whether its rights can be read at all, and what the step says if they cannot.
- Whether `credentials check` tells a dead token apart when the repository is public.
- Where the order stands in the window: on the page of an unset organization, and how it fits a person who already has a card and comes back.
