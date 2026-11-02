# F314 — The Calls Behind The Organization Pages

**Status:** Review.
**Size:** L - the source of the new pages answered by Porelo's commands, *Forges* cut to forge access and "registry" renamed throughout; several days. It needs the written contract of `porelo org …` and `porelo project …` with their `--json` output before it can be planned further.

**What must be true.** The organization's, project's and host's pages and *Connect* show and change the real organization through Porelo's commands, with no checkout of their own. *Forges* keeps only the access to a forge, and the word in the interface is "organization": the interface never asks which one, a machine has one, set at its setup.

## Plan

- `lib/src/ui/organization_host_pages.dart`: what the host's `org status` says is read there. A host admin sees each project's state on the host, and read only, with no action beside it, a locked person and the day their account will be deleted: "locked, account deleted on <day>".
- `lib/src/ui/machine_details_page.dart`, `lib/src/app/registry_pages.dart`: a machine's page offers no action on a person any more: *Admit*, the host lock and unlock, *Delete the account* and *Replace a lost key* on a host go with the registry's operations. A person is locked in their project by its admins; a person no longer a member of any project a host carries is locked there and their account deleted by the host itself.
- `lib/src/app/organization_source.dart`: an implementation over `porelo org …` and `porelo project …`, each answer read field by field, as `doc/Backend-API.md` will say.
- `lib/src/ui/forges_page.dart`: the *Registry* section and *Choose the registry repository…* go; signed in as, Git over ssh, the check, disconnect and used by stay.
- `registry_pages.dart`, `registry_persons.dart`, `registry_read_source.dart` and the `registryRepository` setting go; "registry" leaves texts, commands and documents, except where a GitHub organization or a forge organization is meant, which is always spelled out.
- The host's verbs change with it, hard, with no fallback: `org status`, `org refresh` and `/etc/porelo-host/organization/`. No `org pin` and no renamed `registry pin`: a new host's first pin goes in the machine file `/etc/porelo-host/setup/machine.yml`, written from `porelo org`, as *Prepare a server…* hands it to `porelo-host up --machine-file`. A project's page per machine stays, reached from its page; what it shows of the registry goes.
- No backup key for a project admin: `--project` leaves `porelo identity backup-key`, so that scope leaves `key_recovery.dart` and its dialog; organization owners and host admins keep theirs.
- What the removal of Register and Join left with no caller goes here too: `HostAccess.bringToHost`, `notOnHostYet` and `pendingRevision`, `settings.projectHost`, and `Role.projectAdmin` if nothing takes it.
- Red first: a test of the source against a stand-in answering the contract's written examples.

## Acceptance

- Tests against the contract's examples, with a refusal and an unreadable answer each said in words.
- A search of `lib` finds "registry" in no text a person reads.
- Walked with the other parts on a fresh machine and an organization made anew.

## To be checked

- The contract document, read and answered when it is posted.
- Nothing here has run a real command: every answer is read against the contract's written examples, and real commands wait for Core's cut and the walk. A homeserver's registration token is filed as an idea of its own.

## Compared with the real commands

Read against `org-git-adapter` afe766fa, and taken in: `org projects` for the list until the cut; a repository with no upstream keeps its name and has no address; `org host change` names only what changes; `org create` and `setup --organization` take no `--base`. `project show`'s `stale` and `matrix_registration_entry` are not used here. An empty repository answers 69 `cannot-say`, and a change that may have reached the store answers 65 `exists`, naming its id and `identity revoke --lost`; both are said in the store's words. `org create` refuses `file://`.
