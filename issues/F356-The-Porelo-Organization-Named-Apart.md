# F356 — The Porelo Organization Named Apart

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** A person never has to guess which organization a sentence means. "Create the organization" confuses, because a GitHub organization has the same word and the person has both at that moment; the window says *Porelo organization* wherever both could be meant, and says what it is: it lives in a repository inside the GitHub organization.

## The shape

**The words that change, on the page under *Organization*:**

| Today | Then |
|---|---|
| Create the organization… | Create the Porelo organization… |
| Create another organization… | Create another Porelo organization… |
| Choose the organization… | Choose the Porelo organization… |
| Choose another organization… | Choose another Porelo organization… |
| This computer reads no organization yet | This computer reads no Porelo organization yet |
| Create the organization, Create another organization, Choose the organization, Choose another organization, as a dialog's title | the same, with *Porelo* |
| The organization's repository address | The Porelo organization's repository address |
| What is the organization? | What is the Porelo organization? |

The dialogs' sentences change with them, such as "only a computer that reads no organization yet can fill one".

**The page's help says what it is:** a Porelo organization lives in a repository inside the GitHub organization, and one is not the other.

**The forge's own word where it is known:** "GitHub organization" for GitHub. Another forge is named by its word: from memory, Forgejo and Gitea say organization, GitLab group, Bitbucket workspace. Before an address is given the forge may not be known, and the sentence then says "your forge's organization". GitHub is the forge the window knows by name today.

**What stays:** the navigation item, "Organization". The page it opens has told the person which one is meant.

## Acceptance

- Each word in the table reads as its right-hand side, in the place it stands.
- With an address on GitHub the help says "GitHub organization"; with no address known it names no forge.
- A sentence about the forge's organization and one about Porelo's cannot be mistaken: no sentence holds the bare word where both could be meant.

## To be checked

- The rest of the window's words: about 95 sentences in `lib/src` hold the word, most on the organization page, in `organization_source.dart` and `host_access.dart`; each is read for whether both could be meant. The roles *Organization owner* and *Organization Admin* are read last, as they name a role in Porelo and appear on its own page.
- The words that come from Core, as the window passes them on, follow Core's own change.
