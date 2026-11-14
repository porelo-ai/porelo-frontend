# F574 — My Cards And Keys On Its Own Page

```json
{
  "$schema": "issue-1.json",
  "id": "F574",
  "title": "My Cards And Keys On Its Own Page",
  "state": "Review",
  "size": "S",
  "priority": "Highest",
  "rank": 19,
  "blockedBy": [],
  "covers": "Story ST361: My cards & keys shows the person's key, its validity, agent, organization card and central forge keys in the page's own body, as every rail page does; a dialog stays only for changing the key."
}
```

**Why this size.** One page: the dialog's body moves into the page, and its three callers open the page instead.

**What must be true.** A rail page shows what it is about; nothing is read in a dialog over an empty page.

## Plan

Found live: *My cards & keys* in the rail opens an empty page with only its head, and shows everything in the
modal dialog *My key and card* over it (`identity_view.dart` builds an AlertDialog; `shell.dart` ~963, ~4579 and
~4609 call `showIdentity`).

- The page shows the key, its validity, the agent, the organization card, the central forge keys and *Change my
  key…* in its own body.
- The finder's *My key* command and the other callers open the page.
- A dialog stays only for the change itself.

## Acceptance

- A guard that the page's body shows the key and card and that no dialog opens for reading, red first. The identity tests green.

## Built

- The dialog *My key and card* is now the body of *My cards & keys* (`IdentityPage` in `identity_view.dart`): the key,
  its validity, the SSH agent, the organization card, the central forge keys, the unfinished changes and *Change my
  key…*, read once each time the page is opened, as the dialog was. The rail, the title bar's *My key and card…* and the
  finder's command of the same name open the page; nothing opens a dialog to read the key any more.
- The change of the key goes on in the page itself (the picker, KeePassXC's fields and the review before it runs), as
  it did inside the dialog; the dialogs that stay are those that change something: the proposed card, the first-start
  wizard, a lost key's replacement and the terminals.
- A window built without the identity (only a test of another page) says the key cannot be read there, where the
  rail used to open a dialog running the real `porelo` beside the test.
- `tool/capture_screens.dialogs` no longer names *My key and card*, which opens no dialog; the page is one of the
  screens captured.
- Tests: `test/ui/my_cards_page_test.dart` *My cards & keys shows the key and card in its own body, opening no dialog*
  and *the title bar's My key and card opens the page*, both red before the change (a dialog opened). The test that
  the dialog could be closed while a lost-key plan was held is deleted with the dialog; `test/app/identity_view_test.dart`
  builds the page in its place.
- A pending change's *Use another key* left unconfirmed when the person left the page kept the model replacing that
  change, so on the return a plain *Change my key…* was offered past the pending change and would have replaced it.
  Leaving the page now puts the change back to pending, unless a replacement is already running. *leaving the page
  while another key is chosen leaves the pending change as it was* in `test/app/identity_view_test.dart`, red first.
- The lost-key words name the page as it is now, *My cards & keys*. *the finder's My key and card opens the page, and
  no dialog stays* in `test/ui/my_cards_page_test.dart`, seen red with the command opening nothing.
