# F429 — The Side Bar As A Folding Tree

**Status:** Estimated.
**Size:** XL - the side bar, every leaf page in a new look, *Work* and *Needs you* among them, and a machine's tools
moved from overlays into pages are more than one build; it splits into four parts (below), this issue the first.
estimate=293, the sum of the parts' medians (L 80 + L 80 + M 53 + L 80).

**What must be true.** The side bar shows every place a person works with as a tree: their work, what needs them, each
of their machines with its sections, their forges, projects, cards and keys, and each organization with its sections.
A person reaches a machine's vault or an organization's people from the side bar in a few clicks, never through a
menu, and every page says where it is.

## Why

The design *Porelo Window Side Bar* (updated 2026-11-07) draws the window laid out by what each part acts on, as
[F423](README.md#f423) describes it in words. Against today's window it changes this:

- **Today the side bar is a flat list of six entries** (`ShellRail` in `lib/src/ui/shell_rail.dart`): *Work*, *Needs
  you*, then under *Set up* *My machines*, *My forges*, *My projects* and *Organization*. One machine's tools sit in its
  ⋮ menu and open over the frame (`VaultOpened`, `ConnectionsOpened`, `ProvidersOpened`, `ReadinessOpened`,
  `AgentsOpened` in `lib/src/app/shell_model.dart`, shown by `_opened()` in `lib/src/ui/shell.dart`), always for
  `Machines.current`. The organization is one long page of five lists (`OrganizationPage` in
  `lib/src/ui/organization_page.dart`).
- **In the design, *My machines* and *Organizations* fold open** to each machine and each organization, and those fold
  open to their sections. A section is a page of its own.
- **An entry with entries under it shows no list.** *My machines*, one machine, *Organizations* and one organization
  show a few facts and a row of actions; only a leaf shows a list.
- **Every leaf has one look:** a path line, a large title, a subtitle, a filter field, its main action, and rows with a
  state chip.
- **The organization is changed in the title bar**, by a button naming it, not in the organization page's menu.
- **Today below 840 the side bar sits in a drawer**; the design keeps it beside the page on a tablet.

## Decided

- **Scope:** this issue builds the tree, the pages of facts and actions, the three layouts, and the machine's and the
  organization's sections the window can show today. [F423](README.md#f423) keeps the rest: *My cards & keys* as a
  page, Events, cleaning up under Health, and every section waiting on a call.
- **Ecosystems, Reach per machine, Events, and *prune* and *tighten* under Health are left out** until the daemon
  serves them.
- **Organizations:** the design's shape is the model, several organizations with joining, leaving and working in
  another. Today *Organizations* holds exactly one entry, the organization read; the tree is built from a list, so that
  more entries come with little work once the daemon names them.
- **Tablet:** the side bar stands beside the page from 600 wide; a drawer only below 600.
- **Leaf pages:** every leaf takes the design's look, *Work* and *Needs you* included. What it overrides of earlier
  issues is said under *What it overrides*.
- **Words:** today's words stay: the organization's section is *Machines* (the design's *Hosts*), the foot says *Stop
  everything*, a list of work offers *New work*, and adding a machine is *Watch another machine…*.

## The shape

### The entries, in order

| Entry | Count | Under it | Opens |
|---|---|---|---|
| *Work* | all work, plain | | the list of all work |
| *Needs you* | a badge of what waits | | the list of what waits |
| heading *Set up* | | | |
| *My machines* | the machines | each machine by name | facts: machines and their state, work, what needs you; actions: *Watch another machine…*, *Refresh*, *Stop everything* |
| one machine | | Tasks, Projects, Vault, Credentials, Agents & providers, Health, Managing this machine | facts: Porelo's version and state, the vault's state, tasks, projects, health, the address for a host, when it was last read; actions: *Refresh*, *Lock the vault* or *Unlock the vault…*, *Check whether this machine can run anything*, *Stop Porelo*, *Take down…* |
| *My forges* | the forges | | the list of forges |
| *My projects* | the projects | | the list of projects |
| *My cards & keys* | none | | today's dialog *My key and card…*, until [F423](README.md#f423) makes it a page |
| *Organizations* | the organizations | each organization by name, today one | facts: the one worked in, the person's card; actions: *Change the organization…*, *Create an organization…* |
| one organization | | People, Projects, Machines, Organization owners, Organization Admins | facts: the person's role and card, people, projects, machines, owners, where it is kept; actions from today's organization menu and the row that waits, such as accepting a proposed card |

Every action keeps today's command and its reason when it cannot run; a fact the window cannot read says so.

### States and clicks

- **A chosen entry** is filled with the selection colour and marked as the current page; the entries above it on its
  path are bold, so a person sees which machine or organization a section belongs to.
- **An entry with entries under it** has a chevron, turned down while open. A click on it chooses it and opens it; a
  second click while it is chosen folds it. A leaf has no chevron.
- **A machine that does not answer, or one being prepared, says so on its entry**, since absence is never rendered as
  a good state; the design draws only answering machines.
- **A section opened under one machine shows that machine's**, whichever machine was current before.
- **The foot** holds *Refresh* and *Stop everything*.

### A leaf page

- **Its head:** the path line (*My machines › workstation › Vault*), the large title, a subtitle saying what it holds
  (*3 tasks on 2 machines · 1 running*, *Made · open · 4 entries*), a filter field, and its one main action as a filled
  button (*New work*, *Store an entry…*, *Trust a host key…*). The subtitle counts every row, the filter only narrows
  what is shown.
- **Its rows:** in one white card with a line between rows and no header band; each row its name, a detail line, its
  state as a chip in words with the tone of that state, and its ⋮.
- **The vault** lists names and kinds only, and says that no value is shown, copied or logged.
- **What the design does not draw stays as built:** the sort menu beside the filter, a row's fold and what opens in it,
  *Work*'s switch between *List* and *Running* with its tabs, the groups of *Needs you* with their own titles, and the
  page's explanation, opened from an `i` beside the large title and kept folded across a restart.
- **The pages under a leaf** (one project, one forge, *All projects on your machines*) take the same head, their path
  line one step longer.

### Per layout

- **Desktop:** the title bar keeps today's actions and gains the organization's button on the right. The side bar
  stands beside the page, 260 to 300 wide.
- **Tablet (600 to 839 wide):** the same, the side bar still beside the page.
- **Phone (below 600):** the title bar holds the menu button, the page's title and a small organization button. The
  page has the path line and subtitle, the main action as a full-width button, rows with the chip under the name, and on
  a page of facts the actions stacked under them.
- **Phone, menu open:** the side bar slides in from the left over a dimmed page, with *Porelo* on top and the foot's
  two buttons at the bottom. Choosing a leaf closes it; choosing an entry with entries under it folds it open and keeps
  the side bar open. A click on the dimmed page closes it.

## What it overrides

- **[F344](README.md#f344)**: the header band of a list's card, its title and count in that band, and the filter behind
  a magnifier. The title and count move to the page's large title and subtitle, the filter is a field in the head. The
  narrow forms below 840 and 600 become the phone's form below 600. The sort menu kept per list stays.
- **[F387](README.md#f387)**: the one-line head of *Organization*; its name, warning and "read … ago" go to the
  organization's page of facts, and its lists to their leaves. The `i` beside the title stays, beside the large title.
- **[F381](README.md#f381)**: the explanation's place above each page's card; it opens under the head, from the `i`.
  Its words and its fold kept across a restart stay.
- **[F353](README.md#f353)**: *Work*'s card *All work* with its count in the card's title, and the row's state as a dot
  with words: the count goes to the subtitle, the state to a chip. *Needs you*'s count stands in its subtitle as on the
  badge. The switch, the tabs, the row's fold and its offers stay.
- **[F376](README.md#f376)**: *Work* and *Needs you* without a page title, *New work* at the right of the card's title
  row, the search from a magnifier, the rows under a head of their own colour, and a compact *Needs you* without a
  total. Both pages get the path line, large title and subtitle back; *New work* is the head's main action.

## Plan

### How it splits

Each part is built, tested and handed over on its own, in this order:

1. **The side bar** (this issue's first build, L): the place model, the tree, the four pages of facts and actions, the
   organization's button in the title bar, the three layouts, and *Organizations* built from a list of one. Leaves open
   today's pages until parts 2 to 4 reshape them.
2. **The leaf look and the organization's sections** (L): the shared head and rows, applied to *My forges*, *My
   projects*, one project, one forge, *All projects on your machines*, and `OrganizationPage` split into its five
   leaves.
3. ***Work* and *Needs you* in the leaf look** (M).
4. **A machine's sections as leaves** (L): Tasks, Projects, Vault, Credentials, Agents & providers, Health and Managing
   this machine, each a page for its own machine, in the leaf look.

### Part 1: the side bar

- **The place.** `Section` in `lib/src/app/shell_model.dart` gains a place under it: a machine with one of its sections,
  or an organization with one of its sections. `ShellModel` keeps what is folded open and which place is chosen;
  `goTo` and `openMachine` set both. `itemMachine` and `itemProject` stay for a project's page.
- **The side bar.** `ShellRail` becomes a tree built from `Machines.all` and a list of organizations, today the one
  `OrganizationView` in `lib/src/app/organization_source.dart`: rows of three depths, the chevron, the badge and the
  counts it shows today (`projectsInRail`, `machinesPageRows`, `listedForges`), the selection, the bold path, and a mark
  for a machine that does not answer. `_rail` in `lib/src/ui/shell.dart` passes the place and the fold.
- **Pages with entries under them.** One widget of facts and actions shared by *My machines*, one machine,
  *Organizations* and one organization, its actions as `Command`s with their reasons. `MachinesPage` and
  `MachineDetailsPage` lose their lists to the leaves; `OrganizationPage`'s head becomes the organization's page.
- **The title bar.** `_appBar` in `lib/src/ui/shell.dart` gains the organization's button, opening what *Choose another
  Porelo organization…* opens today.
- **Layouts.** `WindowSize.showsTreeBeside` in `lib/src/ui/window_size.dart` holds from `medium` on; the drawer closes
  on a leaf through `_leaveDrawer`, and stays open on an entry with entries under it. Widths go into `Sizes` in
  `lib/src/ui/tokens.dart`.
- **Red first**, in a new `test/ui/side_bar_tree_test.dart` and new scenarios of `test/features/application_shell.feature`:
  - *a machine's vault is reached from the side bar without its menu* - no tool of a machine only behind a ⋮.
  - *a section under the second machine shows the second machine's* - with the first machine current, the second's
    vault is not the first's; guards a vault or a key shown for the wrong machine.
  - *an entry with entries under it shows no list of them* - guards the right side repeating the side bar.
  - *a second click on the chosen entry folds it* - guards a person losing their place.
  - *a window 700 wide keeps the side bar beside the page* - guards a tablet's page hidden behind a drawer.
  - *a leaf chosen in a phone's drawer closes it, an entry with entries under it keeps it open* - guards a drawer that
    hides the page, or that shuts before the leaf is reached.
  - *each count in the side bar is the rows of the page it opens* - guards two numbers for one word.
  - *a machine that does not answer says so in the side bar* - guards silence read as health.
  - *Organizations lists the organization read, and a second given to the tree is listed beside it* - guards a tree
    that holds only one by its shape.
- The step `the rail lists {…} in this order` and the scenario *a narrow window keeps the rail behind the menu button*
  stay; `test/ui/rail_navigation_test.dart` changes to the tree's keys.

### Part 2: the leaf look and the organization's sections

- `FilteredListSection` in `lib/src/ui/filtered_list_section.dart` takes the head (path line, title, subtitle, filter
  field, sort, main action) and drops its band; `ItemListRow` and `ExpandableListRow` in
  `lib/src/ui/expandable_list_row.dart` take the chip; `PageHead` and `PageExplanation` in
  `lib/src/ui/page_explanation.dart` give the `i` and the explanation under the head. Pages: `forges_page.dart`,
  `projects_page.dart`, `project_details_page.dart`, `organization_host_pages.dart`, `organization_project_pages.dart`,
  and `OrganizationPage`'s `_people`, `_projects`, `_hosts`, `_owners`, `_organizationAdmins` as five leaves.
- **Red first**, in a new `test/ui/leaf_page_look_test.dart`:
  - *every leaf names its path above its title* - guards a list read as another machine's or organization's.
  - *a filter narrows the rows and the subtitle keeps the whole count* - guards a narrowed number read as the total.
  - *a row's state stays in sight as a chip at 390 wide* - guards a state cut off on a phone.
  - *a leaf's main action is in sight at 390 wide* - guards the one action a person came for pushed off screen.
  - `test/ui/page_explanation_test.dart` changes to the `i` beside the large title; a folded explanation stays folded
    across a restart.

### Part 3: *Work* and *Needs you*

- `WorkPage` in `lib/src/ui/work_page.dart` gets the head with *New work* as its action and the *List*/*Running* switch
  under it; `WorkRow` and `AttentionView` in `lib/src/ui/attention_view.dart` take the chip and the white card, the groups
  of *Needs you* each a card under one head.
- **Red first**, new scenarios of `test/features/daily_work.feature` and `test/features/needs_a_person.feature`:
  - *Running keeps its tabs under Work's head* - guards a terminal lost to the new head.
  - *Needs you's subtitle counts what the badge counts* - guards two numbers for what waits.

### Part 4: a machine's sections

- Tasks is `WorkPage` narrowed to the machine; Projects is `MachineDetailsPage`'s project list; Vault is `VaultView`;
  Credentials is `ConnectionsView` and `DestinationsDialog`; Agents & providers is `AgentsView` and
  `AuthenticationView`; Health is `HostReadinessView`; Managing this machine is the managing section of today's machine
  page. Each opens as a page in the leaf look, not over the frame, for its own machine; their `Opened` cases leave
  `_opened()`.
- **Red first**, in a new `test/ui/machine_sections_test.dart`:
  - *each section of a machine reads that machine* - guards a section reading `Machines.current`.
  - *the vault's leaf shows names and kinds and no value* - guards a value on screen.

## Acceptance

- Every leaf of the tree is reached in at most three clicks from a folded side bar, and its page names the path.
- A machine's vault, credentials, agents and health open from the side bar for that machine, with no ⋮ on the way.
- The pages of *My machines*, one machine, *Organizations* and one organization show facts and actions and no list.
- A second click folds a chosen entry; the chosen entry and its path are marked.
- From 600 wide the side bar stands beside the page; below it is a drawer, which a leaf closes and an entry with
  entries under it does not.
- Every leaf, *Work* and *Needs you* included, has the path line, large title, subtitle, filter, main action and chip
  rows; sort, folds, tabs and explanations still work.
- Each count equals its page's rows; a filter does not change it.
- Each red test above seen to fail first, then green; pictures of the four layouts, light and dark.

## To be checked

- Which facts the window can fill today: Porelo's version and state, the vault's state and entry count without opening
  it, health without running the check, when a machine was last read.
- How the overlay views, bound to the current machine's models through `Shell`, are given the machine of their leaf:
  by making it current, or by models per machine.
- Whether a fold of the tree survives a restart, as a list section's fold does in `Settings`.
- What the finder (`command_finder.dart`) marks once a command's home is a leaf, not a menu.
- The walks and the help that name today's menus, page titles and the organization page's lists.
