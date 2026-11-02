# F314 — The Calls Behind The Organization Pages

**Status:** Backlog; blocked by [F309](README.md#f309), [F310](README.md#f310), [F312](README.md#f312) and [F313](README.md#f313).
**Size:** L - the source of the new pages answered by Porelo's commands, *Forges* cut to forge access and "registry" renamed throughout; several days. It needs the written contract of `porelo org …` and `porelo project …` with their `--json` output before it can be planned further.

**What must be true.** The organization's, project's and host's pages and *Connect* show and change the real organization through Porelo's commands, with no checkout of their own. *Forges* keeps only the access to a forge, and the word in the interface is "organization": the interface never asks which one, a machine has one, set at its setup.

## Plan

- `lib/src/app/organization_source.dart`: an implementation over `porelo org …` and `porelo project …`, each answer read field by field, as `doc/Backend-API.md` will say.
- `lib/src/ui/forges_page.dart`: the *Registry* section and *Choose the registry repository…* go; signed in as, Git over ssh, the check, disconnect and used by stay.
- `registry_pages.dart`, `registry_persons.dart`, `registry_read_source.dart` and the `registryRepository` setting go; "registry" leaves texts, commands and documents, except where a GitHub organization or a forge organization is meant, which is always spelled out.
- The host's verbs change with it, hard, with no fallback: `porelo-host-person registry status`, `registry pin <login> <key>` and `registry` become `org status`, `org pin <login> <key>` and `org`, and `/etc/porelo-host/registry/` becomes `/etc/porelo-host/organization/`; what the status answers stays. A project's page per machine stays, reached from its page; what it shows of the registry goes.
- No backup key for a project admin: `--project` leaves `porelo identity backup-key`, so that scope leaves `key_recovery.dart` and its dialog; organization owners and host admins keep theirs.
- What the removal of Register and Join left with no caller goes here too: `HostAccess.bringToHost`, `notOnHostYet` and `pendingRevision`, `settings.projectHost`, and `Role.projectAdmin` if nothing takes it.
- Red first: a test of the source against a stand-in answering the contract's written examples.

## Acceptance

- Tests against the contract's examples, with a refusal and an unreadable answer each said in words.
- A search of `lib` finds "registry" in no text a person reads.
- Walked with the other parts on a fresh machine and an organization made anew.

## To be checked

- The contract document, read and answered when it is posted.
