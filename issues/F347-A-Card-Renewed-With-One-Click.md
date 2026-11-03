# F347 — A Card Renewed With One Click

**Status:** Backlog.

**What must be true.** A card lasts 30 days. A person sees in time that it is ending and renews it with one click in the window; after the end they see that it ended and can still renew it.

## How it stands

Read from the code, not run.

- **Renewing.** No command renews a card with the same key. `identity rotate` refuses the card's own key, and `identity create` makes only a first card. A person can only move to another key, by *Change my key…*.
- **Before the end.** The card's section says *Valid from … until …*, and nothing else. No warning stands anywhere.
- **After the end.** The window shows the same line, in the same color. No search in Core found a check that refuses a card by its `expires`; this is a reading and Core has to confirm it.

## What is needed

- From Core: renewing with the same key, signed through the agent and filed through the store, and whether an ended card may still be renewed. What an ended card stops being good for is Core's to say.
- Here: the words before and after the end, on the card's section and where the person works, and *Renew my card* as one click where the agent holds the key.

## To be checked

- How many days ahead the warning starts. Proposed: seven.
