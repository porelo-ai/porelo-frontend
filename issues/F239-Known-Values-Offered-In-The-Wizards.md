# F239 — Known Values Offered In The Wizards

**Status:** Accepted.
**Size:** M - the host admin's wizards and the project wizards offer what this computer already knows in a list, the likely one chosen, with free entry only for a new value.

**What must be true.** Where the interface already knows the possible values of a field, the wizard offers them in a dropdown, with the likely one preselected. Free entry stays only where a value is new: an account name the person chooses, or a project this computer does not follow. A value taken from a list is checked as a typed one is.

## Why

Operator's finding in walk 23, *Register a project* (steps 5-1 and 5-2), 2026-10-30: "I always type names into a text field. Wouldn't a dropdown with the values already known be better?" Each name typed by hand is a chance to type it wrong. The signing key and the laptop line were copied and hand-assembled from what this computer had already shown.

## Plan

Fields covered (`lib/src/ui/host_admin_dialog.dart` unless named):

- *Register a project*:
  - *Project name*: the projects this computer follows (`ProjectFollowing`), the one selected in *Projects* preselected, plus "Another project…" for free entry.
  - *Project admin account*: the project admins this computer admitted on that host, the last one preselected, plus "Another account…".
  - *Project signing public key*: the signers of the chosen followed project's verified `project.yml`, the one its follow is pinned to preselected. The pasted line stays only for "Another project…".
- *Admit a project admin*: *Laptop public keys* takes the pasted *Copy my public keys for a host…* YAML block (`ssh_public_key`, `wireguard_public_key`), as the developers dialog does. The line is assembled from it with the laptop name and the next address in the host's network that this computer has not given out, shown and changeable. The one-line form stays accepted. The account name stays free; it is new.
- *Lock* and *Purge a project admin*: the account from the admins this computer admitted on that host.
- *Take a project off the server*: the project from those this computer registered on that host.
- *Bring* (`project_bring_dialog.dart`), *Join* (`project_join_dialog.dart`) and *Developers* (`project_developers_dialog.dart`): *Project signing public key file* is offered from the followed project's pinned signing key, written to a file here, instead of a path typed by hand.
- *Developers* (`project_developers_dialog.dart`): the signing key file, the project admin account and the SSH identity are remembered per project once a change was published, and filled the next time (operator, walk 23 step 10-10: asked again each time).
- The admitted admins, registered projects and given addresses are kept with this computer's record of the host when its *Admit* or *Register* is confirmed by the server, and dropped at *Purge* and *Take off*. The host stays the authority. Reading them from the host itself comes with the read-only query contract planned with Agent Machines; until then a value this computer did not record is typed.
- **Red first:** widget tests that *Register a project* preselects the followed project, its pinned signer and the last admitted admin; and that *Admit* assembles the line from a pasted YAML block with the next free address.

## Test

Only the change: the widget tests above and the wizards' own tests. A VM test covers only *Register a project* and *Admit* with the lists, against a stand-in host helper; no rental.
