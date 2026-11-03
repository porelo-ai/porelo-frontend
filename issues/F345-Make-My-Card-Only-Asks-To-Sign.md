# F345 — Make My Card Only Asks To Sign

**Status:** Review.

**What must be true.** A person who already has a key and a forge account makes their card by reading one line and pressing *Sign*. The window asks only what it did not find, or found more than once.

The operator's order of finding:

- The login: from a token or from `ssh -T git@github.com`.
- The key: `git config user.signingkey` when it names an SSH key, then a key in the agent the forge lists as a signing key, then one it lists as an authentication key.
- The name and email: from `git config`, then the forge's public profile.

A key that is not in the agent shows the `ssh-add` line. Porelo still reads no private key.

## How it stands

Read from the code, not run. *Make my card…* in `lib/src/ui/identity_view.dart` opens a wizard, `FirstStartWizard`, that asks who the person is and which key. `identity keys` answers the keys the agent serves with `key_listed`.

## What is needed

- From Core: the found values with where each came from, and what it could not decide. Which form that takes is Core's to name.
- Here: one line with *Sign*, a question only for what is missing or not unique, the `ssh-add` line, and the wizard's path for the rest.

## To be checked

- `identity propose` against real Core; `ambiguous`'s `values` are read as strings or as `{value, source}`, as its form is not yet named. Any other answer opens the old wizard, silently.

- A person whose key is only a signing key: filing the card, vouching, pushing with a second key and logging in to a server with that key. The walks only ran with an authentication key; Core proves this by a test.
