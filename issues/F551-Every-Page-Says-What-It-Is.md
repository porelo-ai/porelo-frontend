# F551 — Every Page Says What It Is

```json
{
  "$schema": "issue-1.json",
  "id": "F551",
  "title": "Every Page Says What It Is",
  "state": "Review",
  "size": "M",
  "priority": "Highest",
  "rank": 7,
  "blockedBy": [],
  "covers": "Every page the window shows carries the i beside its title that opens what the page is and what a person does there; today Planning, My cards & keys, a machine's page and its seven sections, a project's page and the pages opened over the frame lack it. A guard fails on a page shipped without one."
}
```

**Why this size.** About twenty pages across several modules (`shell.dart`, the machine and project pages, the
opened views), each taking an explanation, and one guard test over every place the shell can show.

**What must be true.** Whatever page a person is on, the `i` beside its title opens a short explanation of what the
page is and what they do there; it stands open the first time, as on the pages that have one today.

## Plan

- **The mechanism today** (`lib/src/ui/page_explanation.dart`): a page has its `i` either from `PageHead(id:,
  settings:)`, from `FactsPage(explanationId:, explanation:)`, or from a `PageExplanationScope` whose `title` matches
  a `FilteredListSection` (the shell's `_explained`); `PageExplanation` draws the words, keyed `explanation-open <id>`
  and `explanation-fold <id>`.
- **Measured today**, by a throwaway widget test at 1280x800 over the shell with an organization (`World.work`,
  `organizationFor('olive')`), looking for `explanation-open`: it **has** one on Work, Needs you, My machines, My
  forges, My projects, Organizations and the organization's People, Projects, Machines, Organization owners and
  Organization Admins. It **lacks** one on:
  - *Planning* (`Section.planning`; the board is porelo-planner's package, so the `i` and words stand in the
    window's frame above it);
  - *My cards & keys* (`Section.cards`);
  - a machine's own page (`Section.machine`, no section), and each of its sections: *Tasks*, *Projects*, *Vault*,
    *Credentials*, *Agents & providers*, *Health*, *Managing this machine*;
  - a project's page (`Section.project`, the Default project measured);
  - the pages opened over the frame: operations (`OperationsOpened`), the gate (`GateOpened`), review
    (`ReviewOpened`), egress (`EgressOpened`) and backups (`BackupsOpened`).
- **Read, not measured yet** (see *To be checked*): a forge's page (`Section.forge`), the organization's pages for one
  person, one project and one machine, a work item (`WorkOpened`), one operation (`OperationOpened`), a log
  (`LogOpened`), and a planning story or issue.
- **Steps.** Each lacking page passes an id and its words to the head it already draws (`PageHead` or `FactsPage`),
  or is wrapped by `_explained`; the words say what the page is and what a person does there, in the person's words,
  one or two parts. No new widget.
- **Guard, red first** (harm: a page ships with no way to learn what it is): `test/ui/page_explanation_test.dart`
  gains one test that visits every `Section`, every `MachineSection` of a machine, every `OrganizationSection`, and
  every kind of `Opened` (listed through an exhaustive `switch` on the sealed class, so a new kind does not compile
  until the test names it), and asserts exactly one `explanation-open` on each. It asserts the set it visited equals
  the enums' values, so an empty or shrunken list cannot pass. It goes red on today's code for the pages above. The
  wording gets no test.

## Acceptance

- The guard passes, visiting every section, machine section, organization section and opened kind, and fails when
  one page's `id` is taken out on purpose; each page in the lists above shows its `i` and opens its words.

## To be checked

- The pages read but not measured: measure them with the guard's first run and add any that lack an `i` to the work.

## Left

- **Managing before the organization is read.** On a machine an organization's card names, while the organization's
  list is not read yet or does not name the machine, *Managing this machine* draws the organization's machine page
  with no `i` until the list is read, and then its head over the managing facts' own.
- **Work's words while Running shows.** Work and a machine's *Tasks* keep their explanation mounted offstage under the
  *Running* tab, so its first time can pass unseen there.
