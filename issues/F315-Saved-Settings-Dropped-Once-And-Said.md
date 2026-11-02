# F315 — Saved Settings Dropped Once And Said

**Status:** Backlog.
**Size:** S - one reader of the settings file and one sentence, with tests; a few hours.

**What must be true.** A person whose saved settings come from before the organization model finds them dropped, without a migration, and the interface says so once, in one sentence, on the first start. Nothing asks them to clean up by hand, and the sentence does not come back.

## Plan

- `lib/src/app/settings.dart`: a mark of the settings' form in `frontend.json`; a file without it is put aside as dropped, read no further, and the sentence is due once.
- `lib/src/ui/shell.dart`: the sentence, shown once and then forgotten.
- Secrets are not touched: a credential in the system store or a person's secrets file stays theirs.
- Red first: a settings test with a file of today's form.

## Acceptance

- Tests: a file of today's form starts clean and says the sentence once; a second start says nothing; a file of the new form keeps all it holds; an unreadable file is still refused as today, not taken for an old one.
- Seen to fail by removing the mark.

## To be checked

- Whether a dropped file is deleted or kept beside as a backup: read what a host card's private parts in it would mean, and what `settings.dart` does with an unreadable file today.
- That `frontend.json`'s `machines` keeps the shape other programs read after the drop.
