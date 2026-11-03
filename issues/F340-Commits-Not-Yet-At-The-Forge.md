# F340 — Commits Not Yet At The Forge

**Status:** Accepted.

**What must be true.** A person sees on a project's row and page whether approved commits on the host wait to go to the central forge,
with the action beside it, and who may do it.

**The operator:** *Push the approved main…* stands visible beside the row while commits wait, a second exception to [F329](README.md#f329).

In a walk the operator asked: "It is unclear that I have to push at all, by the ⋮ menu. Where do I see that there is something to
push?" Today nothing says so. *Push the approved main…* stands in the row's ⋮ whether there is anything to push or not.

## The state

Core's answer: the host can work this out with no central token, using the read-only key it already holds for each repository; its
following can keep the result. Only root can read that today, so it takes a person-facing line from the host's command as well as
this interface. Four answers, not a bare number:

| The host says | The row says | Action |
|---|---|---|
| some commits are ahead | `N approved commits not yet at <forge>` | *Push the approved main…* beside it |
| the same | `up to date with <forge>` | none |
| the forge moved on, or the two went apart | `<forge> has moved on: a push would be refused` | *Take the central state…*, where it applies |
| no read key, or the forge out of reach | `cannot say how it stands with <forge>` | the ⋮ as today |

*Cannot say* must never read as up to date. The answer can be up to five minutes old, so it says when it was read, and it only prompts:
the push still decides.

## Who may do it

Read from the code, not run. A person with a working role in the project, not locked, whose role can be read now; connected to the host
under their own card; with a secrets file chosen, from which the central token comes. Where one of these is missing the action stays
visible and greyed with its reason, as the menu does today. Pushing is no admin's privilege, so the row offers it to every member.

## Blocked by

- The person-facing line of the host's command, which is not filed yet.

## To be checked

- Several repositories in one project: the row gives a sum, and its page one line each.
- What [F329](README.md#f329) and [F338](README.md#f338) make of the row's other words beside this one.
