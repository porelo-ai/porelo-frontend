# F153 — A Forge's Token By The Provider's Own Login

**Status:** Accepted.

**Order.** Right after [F152](README.md#f152).

**What must be true.** A person gives a machine access to a forge by the forge's own login: for
GitHub, its device-code login, run in a terminal on the machine, which shows a code and a link
that the person confirms in their browser. The person's own token is the one token: it is kept in
the vault of each machine that uses it, no computer keeps a forge token of a kind of its own, and
no form of the interface takes one. Deploy keys per repository go entirely, as `porelo-project` [PJ69](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj69) sets out.

## Why

The forges view (`forges_view.dart`) asks for a personal access token in a form field of its own,
which the rule in [F152](README.md#f152) forbids. The token is kept in this computer's keychain,
and each machine gets deploy keys made with it; that needs the forge's right to manage keys,
which few people in a company are given, and it is not needed once the machine holds the person's
token. porelo already lends a token from the vault (`git.token.<host>`) to every git command a
machine runs against an `https` remote.

## Acceptance

- Connecting a forge on a machine opens a terminal there running the forge's own login; once it
  succeeds, the token is in that machine's vault and the forge's repositories can be followed and
  pushed to over `https`.
- Binding, unbinding and clearing a machine make or remove no deploy key, and no token stays in
  this computer's keychain; the decisions *A forge's token stays on this computer* and the forge's
  half of *Clearing a machine or a project is one action* are rewritten.
- Seen to fail first: today the forges view takes a token into a text field; the test holding
  that no field takes one goes red on it.

## To be checked

- Which command on the machine runs the forge's login and stores its token in the vault, and
  whether a repository's address must then be written as `https`, since an ssh address needs a key.
- Every place that makes or removes a deploy key: `machine_binding.dart`, `default_view.dart`,
  `forges_view.dart`, `clearing_view.dart` and `machine_clearing.dart`, and `forge.dart`'s calls.
