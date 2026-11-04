# F369 — One Name For The Default Project

**Status:** Backlog.
**Size:** S - words in eight files with their tests, features and two documents.

**What must be true.** The project every machine has carries one name everywhere: the *Default* project. In the foo test the row "Without a project" under *Projects* read oddly to the operator, who gave this word. It is a row with a name, a page and tasks of its own, so it is a project and reads as one.

## Who already says it

**Core and its documents do.** The project is called `default`: `DefaultProject.NAME`, `porelo project default`, `-p default`, and "`default` is the project every machine has". The name is the window's alone to bring in.

## The window's words

| Where | Today | Then |
|---|---|---|
| `projects_page.dart`, the row and its search words | Without a project | Default |
| `project_details_page.dart`, the page's title | Without a project | Default |
| `work_page.dart`, the first start | Skip: work without a project | Skip: work in the Default project |
| `repositories_view.dart`, a repository's action | Work on it without a project | Work on it in the Default project |
| `forges_page.dart`, a repository's actions | Work on it without a project, Stop working on it without a project | Work on it in the Default project, Stop working on it in the Default project |
| `default_view.dart`, the dialog's title | Start work without a project, Repositories worked on without a project | Start work in the Default project, Repositories of the Default project |
| `shell.dart`, the start form's choice | Default: work without a project of its own | Default |
| `fleet_model.dart`, a machine's project line | default — work without a project | Default |
| `commands.dart`, a command and its reasons | Repositories worked on without a project; default is always there: it is where work without a project goes; only default holds repositories without a project | Repositories of the Default project; the Default project is always there; only the Default project holds such repositories |
| `work_page.dart`, the work page's filter | Default | Stays: it says so already |

The code's comments and the tests that name these words follow with them.

**The window's documents too:** `doc/index.md` ("Without a project it runs"), and `doc/decisions.md`, which says "*Projects* lists no *Default*: work without a project starts under *Work*". That recorded decision does not match the row the page shows today, and how they came apart is read when this is built. The features `first_start`, `forge_repositories`, `daily_work` and `one_source` follow, with their generated tests.

## Acceptance

- The window names this project *Default* in each place above, and no visible word says "without a project". Seen to fail first.
- A search for "default" finds its row.
- A real project may not be confused with it: a project named so is refused or told apart, as read below.

## To be checked

- Any further phrase saying the same in other words, when this is built, by reading every visible string on these pages.
- Core's documents use `default`, and also say "without a project" in `doc/commands.md` and `doc/messages.md`, three lines in all, as an explanation of it. They are Core's to judge, and need not change.
- What Core answers for a project named `default` by a person.
