# F347 — A Card Renewed With One Click

**Status:** Review.

**What must be true.** A card lasts 30 days. A person sees in time that it is ending and renews it with one click in the window; after the end they see that it ended and can still renew it.

## How it stands

Read from the code, not run.

- **Renewing.** `Identity.renew` in `lib/src/app/identity.dart` calls `porelo identity renew` with the
  current key and the same operation ID on retry. `IdentityModel.renew` checks the returned key.
  `IdentityRenewal` in `lib/src/ui/identity_view.dart` offers *Renew my card* with one click when the
  agent holds the key, including after the card ends.
- **Before the end.** `lib/src/app/identity.dart` reads Core's `days_left` and `renew_due`, checking
  that renewal is due at seven days or fewer. `IdentityRenewal` shows the warning and action on the
  card and on `OrganizationPage` in `lib/src/ui/organization_page.dart` when these fields are present.
- **After the end.** `IdentityRenewal` shows *Your card ended on …* in the error color, explains that
  ssh refuses the key and project memberships end, and still offers renewal. The person's key file on
  a host carries `expiry-time`, so ssh refuses that key from that moment, the window's ssh with it.
  Root's key has no expiry. Host-side expiry and membership behavior are not checked here.
- **After renewing.** `IdentityRenewal` shows the new end and says each machine takes it at its next
  follow, within five minutes. That follow has not been run here.

`lib/src/app/tunnel.dart` explains an SSH key refusal as an account or key problem, without identifying
an ended card. It does not meet the promised expiry-specific explanation below.
`WorkPage` in `lib/src/ui/work_page.dart` has no card warning or renewal action, so the warning where
the person works is not built there.

## What is needed

- From Core: renewing with the same key, signed through the agent and filed through the store, and whether an ended card may still be renewed.
- Here: the words before and after the end, on the card's section and where the person works, a refused ssh said as the ended card rather than as a machine not answering, the wait of up to five minutes after renewing, and *Renew my card* as one click where the agent holds the key.

## To be checked

- Check an SSH refusal for an ended card on a real machine. `lib/src/app/tunnel.dart` explains it as
  an account or key refusal for a machine's card and for other SSH connections, without naming expiry.
- `identity renew` against a real machine; only Core's contract is read, and fixtures stand for it.

- The warning starts at seven days when Core supplies `days_left` and `renew_due`; a real-machine
  check of that answer is still needed.
