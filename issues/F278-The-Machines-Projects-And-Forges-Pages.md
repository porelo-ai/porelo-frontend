# F278 — The Machines, Projects And Forges Pages

**Status:** Backlog. Estimated and Backlog (operator, 2026-10-30, sprint 6m).
**Size:** L - several days to replace three lists and their item pages, wire registry actions and permissions, and remove tiles without losing commands.

**What must be true.** The *Machines*, *Projects* and *Forges* pages are laid out as the operator agreed on draft 2 (`~/.porelo/handover/porelo-frontend/layout-pj83-v2/layout-pj83-v2.html`, 2026-10-30), as listed under *Decided in the talk*: lists of rows with a ⋮ menu, a page per item with collapsible, filtered lists, no tiles. Each row shows the person's role and the state from the registry, the host's synced state and the tunnel; actions come from the person lists, not from forms with typed names; an action the person may not do names who may, with their email where their card names one.

## Why

One-click joining from signed state (operator, 2026-10-30), the flow's step 7, and the operator's wish to design these pages together (2026-10-30).

Folded in: [F262](README.md#f262), [F263](README.md#f263), [F265](README.md#f265), [F266](README.md#f266), [F267](README.md#f267), and [F239](README.md#f239)'s lists.

## Decided in the talk so far

- *Machines* stays the umbrella: this computer and the remote machines, rented or provided by someone; the proposal's *Hosts* page is the *Machines* page, with the remote machines as its rows (operator, 2026-10-30).
- A project admin may lock a developer in their project, beside the host admin's lock ([F272](README.md#f272)).
- The own identity stays under Settings ([F268](README.md#f268)).
- No tiles anywhere: every page is lists of rows, each row with a ⋮ menu holding its operations; a click on a row opens the item's own page, not a side panel (operator, draft 2, 2026-10-30).
- An item's page shows its own information with one ⋮ on top, then collapsible lists styled like the main list: a machine's *Projects* and *Persons*, a project's *Persons* and *Machines*, a forge's *Registry* and *Repositories* (operator, draft 2, 2026-10-30).
- Every list has a filter field in its header, filtering the rows below it: the top lists *Machines*, *Projects* and *Forges* and each collapsible list on an item's page (operator, 2026-10-30).
- The default project *Without a project*, for starting something by hand outside a real project, always exists on this computer and on every machine, so it always shows: in the *Projects* list as one row per machine and in each machine's *Projects* list, its ⋮ holding *Open* and *Start work*. It is never taken off a machine or locked, so its ⋮ offers neither (operator, 2026-10-30).
- Further remarks follow as the operator goes through the pages.

## Plan

- Use the agreed second layout's right column. Replace expanding cards and primary buttons in `lib/src/ui/machines_page.dart` (`MachinesPage`), `projects_page.dart` (`ProjectsPage`) and `forges_page.dart` (`ForgesPage`, `ForgePage`) with rows: body click navigates; visible ⋮ holds operations. Adapt `lib/src/ui/expandable_list_row.dart` and add collapsible list sections. Every list header has an independent filter, including closed sections. Use `tokens.dart` and `window_size.dart`.
- Join registry roles/admissions, host-applied revisions and tunnel state in a new `lib/src/app/registry_pages.dart` model. Keep these sources distinct. Core's signed cards, `owners.yml` and project access, Machines' sync results, and Gorge's forge access/repositories are agreed shapes, not built APIs; inject fakes. Present the actions from [F270](README.md#f270), [F271](README.md#f271), [F272](README.md#f272) and [F273](README.md#f273), without rebuilding their protocols.
- **Red first:** extend `test/ui/project_room_test.dart`, using `FakeBackend` from `test/features/support/world.dart` and contract fakes. Give two machines identically named projects with different permissions. Open filtered rows and invoke a person action: only the selected host/project/person receives it; forbidden actions send nothing. This prevents changing another person's access. Also fail sync after successful publication: retain confirmed host state and show the pending change.
- Retain explicit item identity in `lib/src/ui/shell.dart` (`Shell`) and `lib/src/app/shell_model.dart` (`ShellModel`, `Section`), including admissions not followed locally. Add `lib/src/ui/machine_details_page.dart` and `lib/src/ui/project_details_page.dart`: back link, information, one top ⋮. Machine sections are Projects/Persons; project sections are Persons/Machines. Preserve `Command` reasons and finder destinations in `lib/src/app/commands.dart` and `lib/src/ui/command_menu.dart`. Move Prepare a server to Machines and setup/protocol/browser/give-back into machine menus.
- Remove `ProjectsPage`'s name grouping and `default` exclusion. Rows show machine, role and admission/register/join state. Show Without a project once per machine, including this computer and disconnected machines, and in machine project lists. Its menu offers Open/Start work, never lock/take off; retain backend identity `default`. Project ⋮ retains Start work, Messages, Review and following, and presents supplied push/pull/backup-key actions.
- Replace Developers and host-admin typed-name entry points with verified person pickers. Project Persons offers add/remove/project lock/let back in; machine Persons offers host lock/let back in/account deletion. Confirm destructive actions with their scope. Unavailable actions name who may, with Write/Copy for an available email; say when no email was supplied. Person cards allow email to be absent, so the existing unconditional email requirement cannot always be met.
- Extend `ForgeConnection` in `lib/src/app/forge_connection.dart` and `ForgePage` with central and tunnel-reached host forges. Add filtered Registry and Repositories sections. Registry menus refresh/file/select/create where permitted; repository menus open/follow/start without a project. Remove automatic token prompts; default to SSH identity. Explicit token use opens the terminal boundary in `lib/src/ui/forges_view.dart`, never a secret field.
- Remove command/project/template tiles from `lib/src/ui/machine_view.dart` and `shell.dart`; replace work tiles in `lib/src/ui/work_page.dart` with rows and menus too. Remove machines-and-keys tools with [F276](README.md#f276). Update affected feature sources and regenerate widget tests. Inspect layout/filtering manually; automate guards for wrong targets, permissions, destructive operations and false success.

## Acceptance

- Walk Machines, Projects and Forges and every item page with a pointer at wide and narrow window sizes. Rows navigate to pages; menus are available without expanding a row. Each nested list collapses and filters independently. No tile presentation remains.
- Compare each role, admission, applied revision and connection indicator with its fake source. Exercise an unapplied change, locked key, lost tunnel, unreadable access repository and failed refresh. None reads as successful sync or an empty authoritative list. Keep the last verified list and name the failure.
- Register, Join, person selection and lock/removal actions target exactly the item opened. Host lock affects the host; project lock affects only that project's repositories and rooms. Refused actions send no mutation and identify who may act, with email actions where supplied.
- Without a project appears once per machine in Projects and in each machine's Projects, even before a remote list arrives. Open and Start work use that machine's `default`; unavailable work explains why. Lock and take-off actions are absent.
- A host forge opens only its tunnel address. Central forge access defaults to the person's identity; the token alternative opens its terminal. No password, passphrase, token or sign-in code is entered in a Flutter form or included in a browser URL.
- During implementation, run affected widget and app unit suites and document checks. Walk the changed pages with stand-ins, then check real registry and host responses on a local VM once the contracts exist. Do not count fake responses as a live integration result.

## To be checked

- Confirm exact Core role, admission, administrator-contact and revision fields, Machines sync/lock results, and Gorge authentication and registry capabilities against their final contracts. Keep unsupported actions unavailable with a reason.
- Inventory commands and finder destinations in `shell.dart`, `commands.dart`, `machine_view.dart` and `work_page.dart`. Account for every removed tile action and preserve review, emergency stop and terminal access.
- Check item identity across machines, registries and repositories. Confirm navigation and filters survive refresh without transferring selection or an operation to another item.
- Confirm the supplied models for gathered push/pull and backup-key actions. Check permissions and results without adding token transport or key creation to page widgets.
- Rehearse empty, loading, disconnected and large lists at narrow sizes. Check filter headers, long names and administrator contacts, menu placement, keyboard focus and the default rows against the agreed layout.

## Estimate

`F278 size=L est=240 basis=guess, no L measured yet`
