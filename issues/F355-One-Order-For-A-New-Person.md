# F355 — One Order For A New Person

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** A new person is given one clear order in the window: do A, then B, then C. Each step shows its state, read and checked before the last step, so *Create it* is reached only when it can work, and a refused step says what to do next in plain words. Today each need is met only as a refusal, in the order the code happens to check.

## The shape

**The order at the start, for creating an organization:**

1. The key is loaded and the card is made.
2. The card's key is listed on the person's forge account, as an authentication or signing key.
3. An empty repository exists in an organization the person owns on the forge.
4. A classic forge token of that same account exists, with its rights named and why they are needed: `repo` for git and for making a project's repositories, `read:org` for asking who owns the organization.
5. The token is in the vault.
6. *Create it*.

Each step shows whether it is done. *Create it* can be pressed when every step before it holds: a key the agent serves, a card, that key on the forge, a token the forge accepts with the rights needed, the person an active owner of the organization, and a repository that is empty. Only the push itself may stay unknown until it is tried.

The order goes on past the organization: the project, its repositories, a host, agents. Those steps are added as the foo test reaches them.

**The token's step says why a token is needed at all:** the forge is asked who owns the organization, only a token can ask that, and an ssh key does not replace it.

## What can be read today, and what cannot

| Step's check | Today |
|---|---|
| The agent serves a key | Exists. `porelo identity keys` lists them, and the window reads it. |
| A card, and its key held | Exists. The window reads the card, and whether the agent holds, does not hold or is absent. |
| The token is in the vault | Exists while the vault is open: the window reads an entry `git.token.<host>` and its length, never its value. An entry in `credentials.yml` naming another place is read too. |
| The card's key is on the forge | Nothing before an organization is settled: `identity show` answers no value until then. Core must add it. |
| The forge accepts the token, and whose it is | Nothing that holds. `porelo credentials check URL` runs `ls-remote`, the window has the call and does not use it, and on a public repository the token is never sent, so a dead one reads as fine. The window's own question, who am I, uses the token in the system's store, not the vault's. Core must add it. |
| The token has the rights needed | Nothing. Core must add it, since the vault's token never reaches the window. |
| The person owns the organization | Only inside `porelo org create`. Core must add it beforehand. |
| The repository can be read as creating reads it | Nothing: `credentials check` uses the account's git configuration, which creating does not. Core must add it. |
| The repository is empty | Nothing that can be asked beforehand. Core reads it only inside `porelo org create`; `credentials check` names a missing repository, not a filled one. Core must add it. |
| The push will be taken | Possibly never: today it is known only by pushing. |

**What Core is asked for:** one question that only reads, given the address, answering each of these apart: repository reached, repository empty, token accepted and whose, the rights it holds or lacks, the person's standing on the forge, and the key listed there. It fills nothing. Its form is not decided yet. Why a failed creation reads as it does is a separate matter on Core's side and stays there; this asks beforehand.

## Acceptance

- A new person with nothing set up sees every step and its state before doing any of them, and no step's need first appears as a refusal.
- *Create it* cannot be pressed with no key served, no card, the key not on the forge, no token, a token the forge refuses, a token of another account, a token lacking a right, a person who owns no such organization, or a filled repository, each against a stand-in forge and seen to fail first.
- No token value reaches a widget or a line of text.

## To be checked

- The right a token needs to add a host's deploy key: `repo` is expected and not measured. `repo` and `read:org` for creating and opening are read in the code and the forge's pages, not yet run by a person following this order.
- A fine-grained token: whether its rights can be read at all, and what the step says if they cannot. The order names a classic one until that is known.
- A repository under a personal account: it has no organization to ask, so it is expected to be refused; what the step says.
- Where the order stands in the window: on the page of an unset organization, and how it fits a person who already has a card and comes back.
