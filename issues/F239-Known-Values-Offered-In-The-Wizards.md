# F239 — Known Values Offered In The Wizards

```json
{
  "$schema": "issue-1.json",
  "id": "F239",
  "title": "Known Values Offered In The Wizards",
  "state": "Idea",
  "size": "M",
  "priority": "Medium",
  "rank": 33,
  "blockedBy": [],
  "covers": "Known values offered: the organization's repository address and the KeePassXC database."
}
```

**Why this size.** the forms of the organization's pages and of a person's identity offer what this computer already knows in a list, the likely one chosen, with free entry only for a new value.

**How it stands.** Held: GUI changes wait until the whole flow has been gone through again.

**What must be true.** Where the interface already knows the possible values of a field, the wizard offers them in a dropdown, with the likely one preselected. Free entry stays only where a value is new: an account name the person chooses, or a project this computer does not follow. A value taken from a list is checked as a typed one is.

## Why

`OrganizationPage` (`lib/src/ui/organization_page.dart`), `OrganizationHostPage`
(`lib/src/ui/organization_host_pages.dart`) and the project pages in `lib/src/ui/organization_project_pages.dart`
offer people and machines from the organization in lists. `OrganizationPersonDialog` in
`lib/src/ui/organization_dialogs.dart` offers people in a dropdown. The organization's pages take the place of the
host admin's and the project wizards, so the fields left are these two.

The repository address in `lib/src/ui/organization_page.dart` and the KeePassXC database paths in
`lib/src/ui/identity_view.dart` still require free entry, without known-value choices. Where this computer knows
those values, these fields do not meet the promise above.

## Plan

Fields covered:

- *The organization's repository address* (`lib/src/ui/organization_page.dart`): the addresses this computer knows, the
  current one preselected, plus "Another address…" for free entry.
- *Your KeePassXC database* (`lib/src/ui/identity_view.dart`): the database this computer knows, preselected, plus
  "Another database…".
- **Red first:** widget tests that each field preselects the known value and still takes a new one.

## Test

Only the change: the widget tests above and the forms' own tests. No VM run.
