# F363 — A Grey Button Says Why In Words

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** A person never finds a grey button with its reason only behind a hover, and is told at the moment of choosing an address what that address will stop later. In the foo test the Porelo organization stood at an https address, nothing said anything at creating, and later *Prepare a machine…* was simply grey.

## Why

- **The reason is only a tooltip.** `HostAccess.noFollowing` says "This organization stands at an https address, and a machine follows it with an ssh key of its own, so a machine made now could never follow it." It is shown as the disabled command's tooltip, on the head of the *Machines* list.
- **Nothing says it at creating.** The dialog for *Create the organization…* takes an https address, and there the address works; the stop comes only at the first machine.
- **A project's addresses have no such check.** The stop reads the organization's address alone. A repository's address is checked for its form only, and its help offers "the SSH one (git@…) or the HTTPS one". Whether a machine can use an https project or repository is the question for Core and the machine's side.

## The shape

- **A disabled action shows its reason as a line of text** beside or under the action, where the person looks, on any list's head. The tooltip may stay.
- **With https:** the line names the address, what the machine needs, and the next step, which comes from Core's answer on how the organization moves to an ssh address.
- **At creating:** the dialog says, once an https address is typed, that a machine cannot follow it, and which form to give, before anything is filed.
- **Project and repository addresses** say the same, if the answer is that a machine needs ssh there too.

## Acceptance

- With an organization at https, the *Machines* list says the reason and the next step in text, with no hover. Seen to fail first.
- Typing an https address when creating says so before *Create it*; an ssh address says nothing of it.

## To be checked

- What a machine reads for the organization, the project repository and each repository, and how each is changed once filed.
- Why the ssh address failed at creating in the foo test, since the words at creating send the person there.
- Every other disabled command on a list's head, which the same line then covers.
