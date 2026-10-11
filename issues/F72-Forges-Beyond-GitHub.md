# F72 — Forges Beyond GitHub

**Status:** Analyzed; blocked by the operator: which forge next.
**Size:** M per forge - a second `Forge` beside `GitHub`, chosen by address, the GitHub-only
reading of an upstream widened, scenarios, and a leg measured against the forge; waits for the
operator to name the forge and give an account there.

**What must be true.** A person whose repositories are at another forge gets the same way from a
repository to work as at GitHub, or is told what that forge does not allow.

## Why

A project from a repository and work in `default` are built and measured against GitHub alone. Each
forge's own API is the interface's; the backend is short of nothing known.

## Plan

- **The seam exists:** `Forge` in `lib/src/app/forge.dart` (`whoAmI`, `repositories`,
  `hasProjectFile`, `repository`, `deployKeys`, `branches`, `hostKeyFingerprints`, `signingKeys`,
  `whyNoKeys`, `addDeployKey`, `removeDeployKey`), with `GitHub` its only implementation, its
  answers through the injectable `ForgeHttp`, and its refusals as `ForgeRefused` in words.
- **A class for the named forge** beside `GitHub`, against that forge's REST API, its refusals in
  words as `GitHub` gives them.
- **Chosen by address:** the default `ForgeFor` in `ForgeConnection`
  (`lib/src/app/forge_connection.dart`) builds `GitHub` for every address; it picks by the forge.
- **Upstreams:** `onGitHub` in `lib/src/app/machine_binding.dart` reads github.com only, and
  `removeAtTheForge` leaves anything else; both ask the forge which upstreams are its.
- **A step the forge forbids** (as a push through Bitbucket's read-only access keys) is refused
  through `ForgeRefused` where it is offered, never left to fail.
- **Red first:** `test/app/forge_test.dart` with the forge's answers through `ForgeHttp`; then a
  scenario in `test/features/project_from_repository.feature` with a repository there; then the
  leg against the forge itself.

## Acceptance

- Each forge offered is measured against the forge itself before the interface names it: a project
  from a repository there, and work in `default` pushed back. Seen to fail: the forge's leg of
  `project_from_repository.feature`, run against the forge, goes red.
- Where the forge forbids a step, the interface says so in words instead of failing silently.
  Seen to fail: a scenario where the forge refuses the step and the words are missing.

## To be checked

- **Which forge comes next.** (the operator's)
- Bitbucket Cloud's access keys are read-only: what a machine's push goes through there. (Agent
  Frontend's, once Bitbucket is chosen)
- **An account, a token and test repositories at that forge** for the measured leg, as `F59` waits
  for them at GitHub. (the operator's)
