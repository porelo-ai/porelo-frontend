# F392 — Work Starts On Its Checkout's Branch

**Status:** Review.
**Size:** M - a checkout's branch read with its origin, carried to `Start` as `from`, and the branch the machine settled said.

**What must be true.** Work a person starts from a checkout on this computer starts from the branch that checkout is on, and says which branch it started from and why that one: the checkout's, the project's base branch, or the repository's default. The person only sees which branch is used; the window names no other.

## Why

The machine cannot see a checkout on this computer, so it cannot know the branch the person is working on; without being told, it starts from the project's base branch or the repository's default, which may not be what the person has in front of them. The daemon takes the branch on `Start` as `from`, and its final reply says which branch the work started from (`baseBranch`) and where that came from (`baseSource`: `CHECKOUT`, `FROM`, `PROJECT` or `DEFAULT`). An older daemon says neither, and then nothing is said of it.

## Plan

- `lib/src/ui/default_view.dart`: *Use a checkout on this computer* reads the checkout's branch (`git symbolic-ref --quiet --short HEAD`) with its origin, and hands both on: to the project its first start names, or to the repository put into default from that origin. An address typed over the origin is another repository and gets none.
- `lib/src/app/start_work.dart`: `CheckoutHere` and `StartWork.checkoutBranch`: the branch goes only with the repository the checkout is of, by the name it was put in as or by its upstream, the same address written another way included.
- `lib/src/ui/shell.dart`: the checkout goes from the dialog into the start form.
- `lib/src/client/porelo_client.dart`: `Start` sends `from` only to a daemon whose `Start` declares it; `StartProgress` reads `baseBranch` and `baseSource`.
- `lib/src/app/fleet_backend.dart`, `lib/src/app/outcome_words.dart`: a start that says its branch yields one line of which and why; the branch this window sent, which the daemon reports as `FROM`, reads as the checkout's.

## Acceptance

- A start from a checkout sends that checkout's branch, for its own repository only; a detached checkout, another repository and every other way to start send none.
- A daemon that does not declare `from` is sent none.
- The started work says its branch and why, for each source; a daemon that says nothing shows nothing of it.

## Decided while building

- The person names no branch: show only, as the operator answered.
- The daemon reports a branch the window sent as `FROM`, as it does for `--from`; the window, which sent it as the checkout's, says it is the checkout's.
- A dry run settles no branch on Porelo 0.5.1~snapshot.4642, so its preview says none.
- VM, the window's backend against 0.5.1~snapshot.4642 on a bare repository with `main` and `feature/x`: sent `feature/x`, the work said "The work starts from feature/x, the branch your checkout on this computer is on."; sent none, "The work starts from main, the repository's default branch."

## Reading by another model

Gemini read the commit; each point taken is fixed with a test seen red first:

- **A checkout with no origin, or a project the checkout named whose file names no upstream:** `CheckoutHere` now keeps
  the checkout's folder and whether its own file or plugins named the project. `checkoutBranch` matches the folder as an
  upstream too. Where no upstream is named, it matches the project's one repository, or the one called as the project, as
  Core's `TaskBase` does. A typed address equal to the folder goes into default with the branch.
- **`sameAddress` against Core's `RepositoryAddress.sameUpstream`:** it now compares host, port and the whole path, so a
  subgroup path, a local path and a scheme's own port match, and two ports of one loopback address do not.
- **A start that failed or was refused said where it started from:** the line is said only once the start went through.
- **Resumed work said its branch was "named for it":** a resume says "The work goes on from <branch>, the branch it
  started from."
- **The tests:** the git fake answers the branch only in the chosen folder, and the project's start checks the folder
  and that the checkout named the project.
- **Not taken:** the point on `_startWorkIn` dropping `repository:` and a `forTest` parameter. Neither is in the commit:
  the call never passed `repository:`, and no `forTest` exists.
- A multi-repository project opened from a checkout still asks which repository: the branch goes with the one the person
  then chooses, by its upstream.

## To be checked
