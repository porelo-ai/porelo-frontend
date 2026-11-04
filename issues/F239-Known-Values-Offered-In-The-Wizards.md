# F239 — Known Values Offered In The Wizards

**Status:** Idea. Held: GUI changes wait until the whole flow has been gone through again.
**Size:** M - the host admin's wizards and the project wizards offer what this computer already knows in a list, the likely one chosen, with free entry only for a new value.

**What must be true.** Where the interface already knows the possible values of a field, the wizard offers them in a dropdown, with the likely one preselected. Free entry stays only where a value is new: an account name the person chooses, or a project this computer does not follow. A value taken from a list is checked as a typed one is.

## Why

`OrganizationPage` (`lib/src/ui/organization_page.dart`), `OrganizationHostPage`
(`lib/src/ui/organization_host_pages.dart`) and the project pages in `lib/src/ui/organization_project_pages.dart`
offer people and machines from the organization in lists. `OrganizationPersonDialog` in
`lib/src/ui/organization_dialogs.dart` offers people in a dropdown. These pages have no *Register a project*,
*Admit*, *Bring*, *Join* or *Developers* wizard matching the field sets below.

The repository address in `lib/src/ui/organization_page.dart` and the KeePassXC database paths in
`lib/src/ui/identity_view.dart` still require free entry, without known-value choices. Where this computer knows
those values, these fields do not meet the promise above.

## Plan

Fields covered (the wizard field sets below have no matching form in the current organization pages):

- *Register a project*:
  - *Project name*: the projects this computer follows, the one selected in *Projects* preselected,
    plus "Another project…" for free entry.
  - *Project admin account*: the project admins this computer admitted on that host, the last one preselected, plus "Another account…".
  - *Project signing public key*: the signers of the chosen followed project's verified `project.yml`, the one its follow is pinned to preselected. The pasted line stays only for "Another project…".
- *Admit a project admin*: *Laptop public keys* takes the pasted *Copy my public keys for a host…* YAML block (`ssh_public_key`, `wireguard_public_key`), as the developers dialog does. The line is assembled from it with the laptop name and the next address in the host's network that this computer has not given out, shown and changeable. The one-line form stays accepted. The account name stays free; it is new.
- *Lock* and *Purge a project admin*: the account from the admins this computer admitted on that host.
- *Take a project off the server*: the project from those this computer registered on that host.
- *Bring*, *Join* and *Developers*: *Project signing public key file* is offered from the followed project's
  pinned signing key, written to a file here, instead of a path typed by hand.
- *Developers*: the signing key file, the project admin account and the SSH identity are remembered per project
  once a change was published, and filled the next time.
- The admitted admins, registered projects and given addresses are kept with this computer's record of the host when its *Admit* or *Register* is confirmed by the server, and dropped at *Purge* and *Take off*. The host stays the authority. Reading them from the host itself comes with the read-only query contract planned with Agent Machines; until then a value this computer did not record is typed.
- **Red first:** widget tests that *Register a project* preselects the followed project, its pinned signer and the last admitted admin; and that *Admit* assembles the line from a pasted YAML block with the next free address.

## Test

Only the change: the widget tests above and the wizards' own tests. A VM test covers only *Register a project* and *Admit* with the lists, against a stand-in host helper; no rental.
