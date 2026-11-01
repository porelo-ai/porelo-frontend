# F295 — No "Ask" Line Naming The Viewer

**Status:** Idea.
**Severity:** low.
**Size:** S - `RegistryRefusal`'s words and the places that build its contacts, with their tests; no contract with
another repository.

**What must be true.** A refusal never ends with "Ask <name> (<login>)." when the named person is the one at this
interface, known from their card key. Where the viewer is one of several contacts, only the others are named. Where
the viewer is the only one, the line says what they can do themselves instead, or nothing.

## Why

The project's own admin reads "… Retry. Ask <name> (<login>)." naming themselves in *Register the project* and in
*Projects you may join*. `RegistryRefusal.toString` (`lib/src/app/registry.dart`) appends " Ask $contacts." from
`whoMay` without knowing who is asking.

## The shape

- `RegistryRefusal` learns the viewer's login, or the contact lists are built without it: the proven person's card
  login, from the identity the registry pages already hold.
- The refusal's own words stay as they are; only the "Ask" line changes.

## Plan

- `lib/src/app/registry.dart` (`RegistryRefusal`), `lib/src/app/project_access.dart` (`_contacts`),
  `lib/src/app/project_join.dart` (`JoinUnreadable`, `JoinUnusable`), and the host access refusals that pass
  `whoMay`.
- **Red first:** a refusal whose only contact is the viewer ends without "Ask"; one with the viewer and another
  names only the other.

## Acceptance

- No refusal shown to a person names that person as the one to ask.
- Contacts other than the viewer are named as today.
