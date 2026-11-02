# F311 — Register, Join And The Developers Dialog Taken Out

**Status:** Backlog.
**Size:** L - about 3000 lines of app code and their tests, reached from the shell, the commands and several pages; several days.

**What must be true.** Nobody registers a project, joins one or adds a developer through a dialog any more: a project is added on the organization's page, a person is added on the project's page, a project is put on a host on the host's page, and a person who belongs to a project finds it ready. No text, command or walk offers what went.

## Plan

- Out: `lib/src/app/project_join.dart`, `project_access.dart` with its core, transport and wiring, `project_developers.dart`, `project_copies.dart`; `lib/src/ui/project_developers_dialog.dart`, `project_bring_dialog.dart`, `registry_address_dialog.dart`; `RegistryOperation.register`, `addPerson`, `join` and `bringState`, and the commands and shell code that reach them. Each is read for what still depends on it before it goes.
- **Not the room's *Join*:** a person joining a project's message room, `joinMessagesCommand` and its features, stay.
- What the removal leaves unreachable goes with it. Tests of what went go; a test of what stays and only reached it through what went is rewritten.
- Texts naming them go, among them the sentence *To add it back, use Register the project again* in `shell.dart`; walks and documents are brought in line.
- Red first: a test that the shell, the commands and the finder offer none of them, which fails today.

## Acceptance

- The test above, and a search of `lib` and `doc` for the words *Register the project*, *Add a developer*, *Project settings: Developers*, *Bring it to the host* and a project's *Join* finds nothing.
- The full suite, `dart analyze` and the document checks are green.

## To be checked

- Which of `registry_pages.dart`, `registry_persons.dart` and `registry_read_source.dart` stay until the calls behind the new pages replace them, and which go here.
