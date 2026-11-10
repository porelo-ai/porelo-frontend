# F355 — One Order For A New Person

```json
{
  "$schema": "issue-1.json",
  "id": "F355",
  "title": "One Order For A New Person",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 45,
  "blockedBy": [],
  "covers": "One order in the window for a person starting from a GitHub organization, with or without a key, each step showing its state, so *Create it* is reached only when it can work."
}
```

**How it stands.** Nothing is built before the foo test.

**What must be true.** A new person is given one clear order in the window: do A, then B, then C. Each step shows its state, read and checked before the last step, so *Create it* is reached only when it can work, and a refused step says what to do next in plain words. Today each need is met only as a refusal, in the order the code happens to check.

## The shape

**The order at the start, for creating an organization:**

A person starts with a GitHub account that owns an organization, mostly one they already have, and often with keys they already have. So the order must not assume "no key yet": what is already done reads as done.

1. A key store ready, KeePassXC being the normal one, serving its keys through its ssh agent.
2. The key and the card, by one of three ways. With no key yet, recommended: `porelo identity create --keepassxc` makes one key inside KeePassXC, with no file, and the card. With a key of one's own: `porelo identity create --key`, naming a key the agent serves, the signing key if two are kept. Or a key made by hand first, then the same. There is no script for it. The card takes only an Ed25519 key, lasts 30 days and is renewed with `porelo identity renew`. It can be made before the key is listed: no forge is asked, so a wrong login shows only at step 7.
3. The public key listed on GitHub, unless it already is. Either type counts. Authentication is the safer one, since a key listed only for signing depends on a GitHub call without a token, which a rate limit can refuse; Signing gives GitHub's Verified badge. An ssh address needs its key as an authentication key.
4. On GitHub: a fine-grained token, its resource owner the organization and its repository access all repositories, with its rights named and why they are needed, kept in the key store. A classic token is no longer the default.
5. Porelo set up on this computer and the token in its vault. The first command is `porelo setup`, which makes the vault with a passphrase asked twice; starting with `porelo vault put` would make one from a passphrase typed once.
6. On GitHub: an empty repository in the organization.
7. *Create it*.

The card's key stays loaded afterwards: a project's task that starts without it runs uncertified, its commits unsigned.

The rights, read in the code and on GitHub's pages, or from memory where marked, and not yet run:

| Right | Why |
|---|---|
| Organization *Members*, read | asking who owns the organization; this one call must answer, or the creation stops |
| Repository *Contents*, write | git, reading and pushing |
| Repository *Administration*, write | making a project's repositories, and adding a host's deploy key |
| Repository *Workflows*, write, from memory | a push touching `.github/workflows`; without it the forge refuses, and nothing names that refusal |

Pull requests are not this token's: an online task's build watch uses a token of its own.

**Two things a person is told at the token's step:** it expires, after which git fails; and the vault's `git.token.github.com` is offered to every https repository on github.com, so a private repository of another organization answers "Repository not found" until that organization has an entry and a token of its own. An organization may also require approval of fine-grained tokens, from memory.

Each step shows whether it is done. *Create it* can be pressed when every step before it holds: a key the agent serves, a card, that key on the forge, a token the forge accepts with the rights needed, the person an active owner of the organization, and a repository that is empty. Only the push itself may stay unknown until it is tried.

The order goes on past the organization: the project, its repositories, a host, agents. Those steps are added as the foo test reaches them.

**A window that lets a person retry the card** should know that, with an organization already chosen, making a card reads that organization first, and a failure to reach it refuses.

**A person who already has a suitable token makes no new one:** the step offers that path and names the rights to check.

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

- A person with nothing set up sees every step and its state before doing any of them, and no step's need first appears as a refusal.
- A person with their keys, their organization and their card already there sees those steps as done, is not pressed to make a new key, and goes on from the first that is not.
- *Create it* cannot be pressed with no key served, no card, the key not on the forge, no token, a token the forge refuses, a token of another account, a token lacking a right, a person who owns no such organization, or a filled repository, each against a stand-in forge and seen to fail first.
- No token value reaches a widget or a line of text.

## Open questions

- A login on a card must be lower case, start with a letter and be at most 32 characters, and GitHub allows more, from memory. Should the pattern change, or does the step only say so?

## To be checked

- The rights above, by a real run of a fine-grained token: the foo test measures them now. Whether making a repository needs *Repository creation* beside *Administration* is not confirmed.
- Whether a fine-grained token's rights can be read at all, and what the step says if they cannot. A classic token's scopes can be read; a fine-grained one may show only by trying.
- A repository under a personal account: it has no organization to ask, so it is expected to be refused; what the step says.
- Where the order stands in the window: on the page of an unset organization, and how it fits a person who already has a card and comes back.
