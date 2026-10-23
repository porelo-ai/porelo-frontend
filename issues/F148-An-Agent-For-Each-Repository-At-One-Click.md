# F148 — An Agent For Each Repository, At One Click

**Status:** Accepted.

**What must be true.** On a machine where the person has a project, the interface starts, at one
click, a task for each of the project's repositories that names an agent in `project.yml`, each
with that agent. The person can leave out repositories before the start and give each task the
values `issue` and `phase` (`porelo`
[B189](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b189)) where the project
declares them. An agent that is not signed in there is signed in on the way, as at a single task's
start. Tasks already running are not started twice.

## Why

`host up` no longer starts tasks (`porelo-project`
[PJ40](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj40), decided
2026-10-23): the machine and the work on it are kept apart. Starting a project's agents is the
person's step after `up`, and with a dozen repositories, one task at a time is too slow. It is the
same on the rented host as on any machine.
