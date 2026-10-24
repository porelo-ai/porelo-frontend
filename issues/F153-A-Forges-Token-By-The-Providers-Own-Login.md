# F153 — A Forge's Token By The Provider's Own Login

**Status:** Backlog; ships together with `porelo` [B269](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b269), which retires the daemon's deploy keys.
**Size:** L - the forges view, the deploy keys in five modules, the token's two places, the decisions; with porelo.

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

## Plan

- **The split, as `porelo-project` [PJ69](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj69) sets it out:** git (clone, fetch, push) takes the
  person's ssh key for an `ssh` address or their token for an `https` one, and both stay; the
  forge's API takes the token only. This computer keeps the person's own token for the API calls it
  makes (repositories, `porelo.yml`, branches, host-key fingerprints, signing keys); each machine
  keeps it in its vault for git over `https`. No token of another kind, and no deploy key.
- **Today**, read in the code: the forges view (`forges_view.dart`, `forges_page.dart`) takes a
  token into a field and keeps it in the keychain (`ForgeTokens`, `forge_connection.dart`); deploy
  keys are made and removed in `machine_binding.dart`, `default_at_forge.dart`, `default_view.dart`,
  `forges_view.dart` and the clearing (`machine_clearing.dart`), through `GitHub.addDeployKey`,
  `removeDeployKey`, `whyNoKeys` and the daemon's `DeployKey` (`FleetBackend.deployKey`).
- **Built now with the token pasted**, the forge's device-code login later in the same terminals,
  once porelo names an OAuth application for it.
- **The token on this computer, typed only in a terminal:** the field goes. *Connect a forge*
  opens a terminal on this computer running `porelo-host key set <forge address>`, whose own
  prompt reads the token without echo into the system secret store, the same store and entry
  `ForgeTokens` reads; `porelo-host`'s `key set` and `key forget` take a forge's address beside
  `scaleway`. The interface reads the token from the store when it calls the forge, as today.
- **The token on a machine, typed only in a terminal there:** binding a machine to a forge opens a
  terminal on that machine running `porelo vault put git.token.<host>`, porelo's own prompt.
  Whether it is there is read from the vault's listing, by name; no value crosses the socket.
- **Deploy keys go:** every call that makes, lists, checks or removes one, `whyNoKeys`, and the
  `DeployKey` call; a key made earlier is still named by porelo's unfollow and clear, as porelo [B269](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b269) keeps.
  The decisions *A forge's token stays on this computer* and the forge's half of *Clearing a
  machine or a project is one action* are rewritten to what holds then.
- **Tests, their harm, red first:** no field of the interface takes a token (today the forges view
  does); clearing and binding make and remove no deploy key; the token reaches the forge only in its
  header, as today; `key set` for a forge reads only from its terminal, never an argument.

## Acceptance

- Connecting a forge opens a terminal on this computer running `porelo-host key set <forge>`, and
  binding a machine opens a terminal there running `porelo vault put git.token.<host>`, the person
  pasting their own token at each prompt; once it is in, the forge's repositories can be followed
  and pushed to over `https`. The forge's device-code login opens in the same terminals later, once
  porelo offers it, as an issue of its own.
- Binding, unbinding and clearing a machine make or remove no deploy key, and no token stays in
  this computer's keychain; the decisions *A forge's token stays on this computer* and the forge's
  half of *Clearing a machine or a project is one action* are rewritten.
- Seen to fail first: today the forges view takes a token into a text field; the test holding
  that no field takes one goes red on it.
