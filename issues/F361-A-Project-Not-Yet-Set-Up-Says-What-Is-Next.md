# F361 — A Project Not Yet Set Up Says What Is Next

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** The row of a project not yet set up shows one clear next step as a button that goes straight into that dialog, and once it is set up the menu goes to the project in plain words. No word means two things: today "Open under Projects" names a place in the side bar and goes there, while *Open the project* makes a repository and signs.

## The shape

**Proposed words:**

| Where | Today | Then |
|---|---|---|
| The row, not set up, for its Project Admin | nothing about what is next | a button, *Set up the project…* |
| The row, not set up, for anyone else | nothing about what is next | "Waits for <admin> to set it up." |
| The menu, once set up | Open under Projects | Go to the project |
| The project's page, not set up | "This project has not been opened yet. Opening it makes its project repository, signed by you." | "This project is not set up yet. Setting it up makes its repository on the forge, signed by you." |
| The project's page's button | Open the project | Set up the project… |
| Its dialog's title and button | Open <project>?, Open the project | Set up <project>?, Set up the project |
| *Add a project*'s words | "when they first open the project under Projects" | "when they set it up, on its row" |

**The review choice.** `_alone` starts on No beneath the question "Do you work alone?", so a switch answers a question nobody has yet read. It becomes a choice with neither side taken, *Someone else reviews: review required* and *I work alone: review optional*, and *Set up the project* waits for it. Both can still be changed later from the project's menu.

**The menu's order.** *Fill it from a checkout…* no longer stands first. It reads a checkout folder and files what it finds as a signed commit in the project's own repository, so it is for a person with a checkout they already have, and it comes after setting up. A person who adds repositories by address never needs it.

**What a page of a project not yet set up leaves out.** These stand before the one thing to do today:

- "Porelo does not name the current review policy, so this page cannot say whether review is required.": no sentence for this state, so no review line until it is set up.
- "Project repository: none named yet" says what the line above already says, so it goes until set up.
- "Repositories 0" offers no way to add one, and adding comes after setting up. The list says so in words: "Add repositories once the project is set up."

## Acceptance

- A project not set up shows its button to its Project Admin and the waiting words to anyone else; the button opens the dialog at once. Seen to fail first.
- *Set up the project* cannot be pressed before the review choice is made.
- Once set up, the row has no such button, and the menu's *Go to the project* opens its page.
- No word on these pages says "open" for setting up.
- A project not set up shows no review line and no repository line, and its empty list says what comes first.

## To be checked

- Whether the organization page's row can tell a project not yet set up, and has the revision the dialog needs, without reading each project first.
- *Fill it from a checkout…* before set-up: it stands in the menu with no such condition, and it files into a repository that does not exist yet. What it answers then, and that an Organization Admin who is not the Project Admin is offered it, where Core gives that role no right in the project's own repository.
- The command's own word stays `porelo project open`, which is Core's to say if it follows.
