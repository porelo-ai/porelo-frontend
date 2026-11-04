# F72 — Forges Beyond GitHub

**Status:** Estimated; the next forge is Bitbucket Data Center, Cloud after it; blocked by the
operator's evaluation licence for the test installation when it is built.
**Size:** L for Bitbucket Data Center - a second `Forge` beside `GitHub`, on a host the person
names rather than one known address, the GitHub-only reading of an upstream widened, scenarios, and
a leg measured against a test installation of its own, set up on a VM. Each forge after it is M.

**What must be true.** A person whose repositories are at another forge gets the same way from a
repository to work as at GitHub, or is told what that forge does not allow.

## Why

`GitHub` is the only `Forge` implementation in `lib/src/app/forge.dart`. The interface lists its
repositories and offers work in `default`. Each forge's own API is the interface's; the backend is
short of nothing known.

A project is filled from a checkout ([F350](README.md#f350)), not from a form at the forge, and the interface
places no key on a repository: a machine follows the organization.

## Bitbucket Data Center first

Bitbucket Data Center comes first, Bitbucket Cloud later. The build side, a push's builds read
from Bitbucket Data Center and Jenkins, is not this issue.

- **On the organisation's own host:** its REST API is `https://<host>/rest/api/1.0/…`, so a forge is
  added with its address, not recognised by one; an upstream is Bitbucket's when its host is one of
  the Bitbucket forges added here. Its repositories live in projects (`/projects/<KEY>/repos/<slug>`)
  and in personal spaces (`~<user>`). Clone addresses are `ssh://git@<host>:<port>/<key>/<slug>.git`,
  the ssh port often not 22, and `https://<host>/scm/<key>/<slug>.git`.
- **Personal access tokens,** sent as `Authorization: Bearer`, each with a permission for projects
  and repositories (read, write, admin).
- **What GitHub gives that it may not:** the host keys of its ssh endpoint, which GitHub publishes
  in `/meta`, and the signing keys of a person. Where it gives neither, the interface says so and
  the person compares the host key with what the administrator publishes, as for an unknown forge.

**The measured leg, against a test installation of its own:**
- Atlassian's container image of Bitbucket Data Center on a VM of ours, with its embedded database,
  under Atlassian's evaluation licence, its web and ssh ports reached from the build only.
- **The operator provides** the evaluation licence, made at Atlassian for the installation's server
  ID; it is typed into the installation's setup on the VM, and never into a file in a repository or
  the channel. The agent sets up the container, a project, test repositories of the installation's
  own, a test user and its token.
- The leg runs `forge_repositories.feature`'s Bitbucket scenarios against it, on the operator's
  word for a release, not in every build, since the evaluation licence runs out and is renewed by
  hand.

## Plan

- **The seam exists:** `Forge` in `lib/src/app/forge.dart` (`whoAmI`, `repositories`,
  `hasProjectFile`, `repository`, `branches`, `hostKeyFingerprints`, `signingKeys`), with `GitHub`
  its only implementation, its answers through the injectable `ForgeHttp`, and its refusals as
  `ForgeRefused` in words.
- **`BitbucketDataCenter`** beside `GitHub` in `lib/src/app/forge.dart`, against REST 1.0: who the
  token is, repositories by project and by name, `project.yml` read through `/raw/`, branches,
  and its refusals in words as `GitHub` gives them.
- **A forge with an address:** `ForgeForm` (`lib/src/ui/forges_view.dart`) already asks for the
  installation's address; `ForgeConnection.add` (`lib/src/app/forge_connection.dart`) already
  accepts and keeps it, with token entry in a terminal. Use them for the Bitbucket installation.
- **Chosen by address:** the default `ForgeFor` in `ForgeConnection`
  (`lib/src/app/forge_connection.dart`) builds `GitHub` for every address; it picks by the forge's
  host, Bitbucket's being the address the person gave.
- **Upstreams:** `onGitHub` in `lib/src/app/machine_binding.dart` reads github.com only; upstream
  recognition asks the forge which upstreams are its.
- **A step the forge forbids** is refused
  through `ForgeRefused` where it is offered, never left to fail.
- **Red first:** `test/app/forge_test.dart` with the forge's answers through `ForgeHttp`; then a
  scenario in `test/features/forge_repositories.feature` with a repository there; then the
  leg against the forge itself.

## Acceptance

- Each forge offered is measured against the forge itself before the interface names it: its
  repositories listed, and work in `default` pushed back. Seen to fail: the forge's leg of
  `forge_repositories.feature`, run against the forge, goes red.
- Where the forge forbids a step, the interface says so in words instead of failing silently.
  Seen to fail: a scenario where the forge refuses the step and the words are missing.

## To be checked

- **Bitbucket Data Center's answers,** measured against the test installation: a token's identity, a
  refusal for a missing right, whether it publishes its ssh host keys or a person's signing keys
  anywhere through REST. (Agent Frontend's)
- **The container's needs on the VM:** memory, disk, and the image's current version. (Agent
  Frontend's)
