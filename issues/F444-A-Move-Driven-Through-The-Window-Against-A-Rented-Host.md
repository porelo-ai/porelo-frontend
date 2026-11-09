# F444 — A Move Driven Through The Window Against A Rented Host

**Status:** Review.
**Size:** M - a local VM that runs the window under a virtual display, one feature file of a move's main scenarios
reusing the steps of the suite against a leased machine, its report, and one try on a rented server.

**What must be true.** The main scenarios of a move are driven through the real window, unattended, against a rented
host that is already set up, acting as one test person, and each step checks on the host itself what the window made
happen. The window runs in a local VM with no desktop, so no window, notification or keyboard focus ever reaches a
person's display.

## Why

A move's faults in the window show today only in the operator's own test, after the host is rented and set up. Every
Build already drives the window against a leased machine (`tool/e2e.sh` and the suite in `integration_test/`), but
against a single machine, not a host of an organization with its projects, tasks, builds and gate.

## What it builds against (in words)

- **The host:** a rented server on which `porelo-host`'s set-up has run, with its forge, its runner, the project's
  room and porelod; it follows a test organization whose every role (owner, machine admin of the host, project admin,
  developer) is one test person. Its address is given to the run.
- **The test person:** a login on the host and on the central forge, an ssh key and a forge token of that person
  alone, reaching that test organization and nothing else. The key is used through an ssh agent forwarded from the
  computer starting the run; the token is read from that person's own vault there and given on standard input only.
- **The agents' provider:** one reached by an API key from the test person's vault, so no browser is needed.
- **What the window sees** is the daemon's contract as served (`org.fuin.porelo.Tasks1`), nothing more.

## Plan

- **The VM:** Ubuntu 24.04 under libvirt, no desktop; Flutter from its tarball (not the snap, which needs a person's
  D-Bus session); Xvfb through `xvfb-run -a -s '-screen 0 1280x800x24'`, `GDK_BACKEND=x11`, `WAYLAND_DISPLAY` unset, and
  a `notify-send` that shows nothing first on the PATH, as `tool/e2e.sh` sets them. The test person's key never enters
  the VM.
- **`integration_test/rehearsing_a_move.feature`**, run by `tool/e2e.sh` with the host's address, each scenario checked
  on the host over ssh:
  - the host listed and connected from the organization's card; its facts page answers;
  - the organization's pages: the host, its machine admin, the project;
  - the project on the host: each repository carried or not, its state at central, its tasks, as the host says them;
  - *New work*: the start's check, the model it will run, the task's name; the task started;
  - the batch start: one task per repository, nothing signed in twice;
  - *Needs you*: a grant a start asks for, granted from there;
  - the builds on a task's tile once the host's runner built its first push;
  - the gate's review of a task's push (its commits and who made them) and the push to the host's forge;
  - *Take Porelo off* for the project, as far as the window does it.
- **The report:** one line per scenario, `OK` or `FAIL`, from `tool/test_report.dart`, with the screen's text on a
  failure, into the run's directory; fail-fast; a time budget of its own (about 60 minutes), after which the window's
  part is stopped and the run goes on without it.

## Acceptance

- One run against a rented host passes every scenario above, or names the one that failed with the screen's text and
  what the host said.
- During the run nothing appears on the display of the computer that started it: no window, no notification.
- No key leaves the computer that started the run; no token is on a command line, in a log or in the report.

## To be checked

- Whether the host's runner builds within the time budget, or the builds scenario waits longer than the rest.
- Whether a task's first push needs anything typed on the host; if it does, the scenario stops before it and says so.

## How it stands

- `tool/rehearse_window.sh check` names what the VM lacks and the line that installs it, and whether its account
  follows an organization; `run` copies HEAD to the VM, fetches the pinned Flutter checked against its published
  sha256, takes every value only in the form it can have (no quote, space or leading dash reaches a command line
  on the VM), trusts only the host key it is given and stops where the VM knows another for the address, forwards
  the test person's agent for the run alone with no X11 forwarding, stops the window's part after
  `--budget-minutes`, and writes `scenarios.txt` (`OK`, `FAIL` or `SKIPPED` per scenario), the
  HTML and JUnit report and the run's output. The VM's copy and the host's key in its known hosts are taken away
  on every ending, and what still runs of the window's part there is stopped. It exits 0 only where every scenario
  says `OK`.
- `tool/test_report.dart --lines=` writes the line per scenario; a skipped one is never `OK`.
- `tool/e2e.sh` keeps the account's settings only with `PORELO_E2E_OWN_SETTINGS=1`: the window reads the
  organization through the local `porelo`, from the card that account holds. Every other run starts from nothing.
- `integration_test/rehearsing_a_move.feature`, each step comparing the screen with the host's daemon (asked over
  the contract with `varlinkctl`) or its `porelo build status`: the host connected from its row on the organization's
  machines (a host connected before the run is a failure there); the
  organization's machines listing it with the project; the project's repositories carried as the host says; work
  started under the name and model the window showed; the batch, one task per carried repository; a task's work
  waiting at its gate reviewed from *Needs you* (commit, author), forwarded to a new branch `rehearsal-<time>`
  (never the default) until the host no longer holds it, found at the host's forge at that commit, and the tile
  naming the build the host's daemon read for that commit, failed where the host says so.
- agy's reading (gemini-4-argon-high), not ready: three steps used the wrong page or button (connect from *My
  machines*, the review from *Work*, the batch's Start on its first page), checks that passed on empty values or on
  "carried: not read", a builds check that compared nothing, quoting of the values into the VM's command lines, the
  shared known hosts, a stale report and an exit 0 without scenarios. All fixed. Not taken: `test_report.dart`
  counting a skip as no failure, which the Build relies on for the live daemon's tests; the rehearsal reads the
  lines instead.
- **Not built:** a grant under *Needs you* (only if a start asks for one, which the run cannot bring about), and
  *Take Porelo off*, which removes Porelo from the rented host; the host rehearsal returns the server anyway. Either
  is added if the review asks for it.
- **Not yet run:** the VM lacks `libsecret-1-dev`, the test person's card and the organization; `check` says each.
  The operator installs the package. Core's answer: the card (`identity/card`, `key.pub`) and `organization.yml`
  are copied into the VM account's porelo settings directory, public files only; `run` stops unless
  `porelo identity show --json` there says the forwarded agent holds the card's key.
- Fail-fast is the budget alone: the scenarios share one host, and a red one stops none after it.

