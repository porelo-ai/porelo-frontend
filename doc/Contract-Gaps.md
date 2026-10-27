# What the contract does not yet cover

What the interface needs that `org.fuin.porelo.Tasks1` has no method or field for yet. Once nothing
is left, the page goes.

A convincing screen with no method behind it is the most expensive kind of wasted work, because
it looks finished.

## The rule that makes these real gaps

- **The interface never parses the `porelo` CLI.** One that did would be a second implementation of
  every refusal the product makes, and those refusals are the product.
- **The interface never reads or writes the backend's files.** Over a forwarded socket there is no
  filesystem on that machine at all, so the API is the only way in.

Both rules, and why running `ssh` is not a breach of the first, are in [AGENTS.md](https://github.com/porelo-ai/porelo-frontend/blob/main/AGENTS.md). A
gap here is a backend method that has to be added, not a workaround waiting to be found.

## Not on the wire yet

- **Whether an agent is waiting on a person for its own question.** `WAITING` covers clearance
  questions only. The backend will observe working and quiet from outside for every agent, and let
  each agent declare waiting where it can; until then a quiet task is shown as a guess.

- **Clearing away a project left from before following** (decided in Porelo, not built).
  `Unfollow` with `dryRun` answers `NoSuchProject` for a project the machine still lists but does not
  follow, so *Stop following* has nothing to show and nothing is removed from here; a blind `force`
  is not offered, because what it destroys includes pushes nobody reviewed. Porelo's change makes the preview
  answer `PREVIEWED` with `removes`, `keeps` and `unreviewed`, and the refusals a followed project
  gets.

- **Where content Porelo delivered into a task came from.** The ranked review shows what a push
  changes in the machine's order, and would show the origin of what reached the task beside it;
  `Review` does not carry it yet.

- **Matrix in `porelo doctor`.** Whether a machine can carry messages, the transport and its
  homeserver answering, is shown for a project; the machine's own readiness does not include it.

- **A central homeserver shared by several machines**, which `porelo-message-matrix` plans. Until it is
  there, a machine's `Project.messages` says it is not admitted, with its address and the room, and
  a person invites each machine's account from a client of their own.

- **The agent a repository names.** `project.yml` has no `agent` key under a repository, and
  `Repository` carries none, so starting an agent for each repository at one click has nothing to
  read which agent that is.

## On the wire, not used here yet

- **`WatchProjects`**, a push for what `Projects` answers. The project row still asks again after
  anything that would change it; moving it onto the push makes its counts arrive rather than age.

## What becomes of a gap

A gap is closed by a backend method, raised as a requirement in the `porelo` repository: adding one
is additive and costs nothing under the compatibility promise. A local workaround would not
survive the first remote backend. What has landed is taken off this page.
