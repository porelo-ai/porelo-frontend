# F437 — Join, Leave And Accept A Card In The Window

**Status:** Accepted, for estimation.

**What must be true.** A person who cannot write an organization's repository asks to join it from the window, by
filing their card as a proposal; an owner sees the proposal on the waiting person's row in *People* and accepts it
there; and a member leaves an organization from the window, which withdraws their own card and roles and forgets the
organization on this computer.

**Blocked by** the backend's card proposal and acceptance (a card filed as a proposal by a person who cannot write
the repository, accepted by an owner) and its `porelo org leave` (one's own card withdrawn, one's roles revoked, the
organization forgotten on this machine), each readable and callable by the window.

## Why

The operator's word (2026-11-08): card proposal and acceptance, yes; leaving an organization, yes. The side bar's
organization pages show *Join an organization…*, *Accept a proposed card…* and *Leave <organization>…* as actions
waiting for a command; until the backend offers them, they stay greyed.

## What it would be

- **Join an organization…:** after the organization is chosen (as today), a person who cannot write its repository
  files their card as a proposal, and the window says that it waits for an owner.
- **Accept a proposed card…:** on each proposed card's row in *People*, for an owner only, an *Accept* that files the
  acceptance; the row's chip says proposed until then. The organization's own button goes.
- **Leave <organization>…:** asks once, names what goes (one's card, one's roles, the organization on this computer),
  then leaves; a refusal says why in the backend's words.

## Size

M with the backend's commands as named above; S of it is the join, S the acceptance, XS the leave.
