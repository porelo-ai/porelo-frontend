# F295 — No "Ask" Line Naming The Viewer

```json
{
  "$schema": "issue-1.json",
  "id": "F295",
  "title": "No \"Ask\" Line Naming The Viewer",
  "state": "Idea",
  "size": "S",
  "priority": "Medium",
  "rank": 21,
  "blockedBy": [],
  "covers": "No refusal ends with \"Ask <name>\" when the named person is the one at this interface."
}
```

**Why this size.** `RegistryRefusal`'s words and the places that build its contacts, with their tests; no contract with
another repository.

**Severity.** Low.

**What must be true.** A refusal never ends with "Ask <name> (<login>)." when the named person is the one at this
interface, known from their card key. Where the viewer is one of several contacts, only the others are named. Where
the viewer is the only one, the line says what they can do themselves instead, or nothing.

## Why

`HostAccess._ask` in `lib/src/app/host_access.dart` filters out `view.me` before naming contacts.
`OrganizationRefused.toString` in `lib/src/app/organization_source.dart` returns the supplied words without adding
contacts. `IdentityRefused.toString` in `lib/src/app/identity.dart` appends " Ask $contacts." from every entry in
`whoMay`, without filtering the viewer. That file does not meet the promise above when Core includes the viewer.

## The shape

- `IdentityRefused` learns the viewer's login, or the contact lists are built without it: the proven person's card
  login, from the identity the organization pages already hold.
- The refusal's own words stay as they are; only the "Ask" line changes.

## Plan

- `lib/src/app/identity.dart` (`IdentityRefused`, `Identity._contacts`),
  `lib/src/app/organization_source.dart` (`OrganizationRefused`), and `lib/src/app/host_access.dart` (`_ask`).
- **Red first:** a refusal whose only contact is the viewer ends without "Ask"; one with the viewer and another
  names only the other.

## Acceptance

- No refusal shown to a person names that person as the one to ask.
- Contacts other than the viewer are named as today.
