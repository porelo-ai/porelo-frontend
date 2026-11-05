# F361 — A Project With No Git Repository Yet

**Status:** Review.
**Size:** M - a project's new place on the Organization page, its words, a row in *Needs you*, and the same for a machine with no address.

**What must be true.** A project whose Git repository does not exist yet says exactly that, and the person who can create it learns of it and does it in one place, in words that say what happens. "Opened" is out: today "Open under Projects" names a place in the side bar and goes there, while *Open the project* makes a repository and signs.

**Decided:** the command is `porelo project create-repository`, and adding and creating are one step when the person adding names themselves as Project Admin, with the review choice moving into *Add a project* then. *Needs you* holds the row for the named Project Admin alone.

## The shape

**Where it happens.** A project with no repository yet does not stand under *My projects*. It stands on the Organization page, and the step is done there, on its row. Once the repository exists it appears under *My projects*.

**The words:**

| Where | Today | Then |
|---|---|---|
| The Organization page's row, for its Project Admin | nothing about what is next | "foo-project has no Git repository yet.", with a button *Create the project's Git repository* |
| The same row, for anyone else | nothing about what is next | "foo-project has no Git repository yet. It waits for <admin>." |
| The row's menu, once it exists | Open under Projects | Go to the project |
| The dialog's title and button | Open <project>?, Open the project | Create the Git repository of <project>?, Create the project's Git repository |
| The dialog's text | "Porelo makes the project repository and signs its first project.yml with your key." | the same fact, also naming where: the organization's forge, private and empty |
| *Add a project*'s words | "when they first open the project under Projects" | "when they create its Git repository, on its row here" |

**How its Project Admin learns of it: a row in *Needs you*,** with the same sentence and button, for the project's named Project Admin alone. The Organization Admin role gives no right there, so that role gets no row. It counts like every other row. Today nothing tells them.

**The review choice stays in that dialog,** since it goes into the first `project.yml` written there. `_alone` starts on No beneath the question "Do you work alone?", so a switch answers a question nobody has yet read. It becomes a choice with neither side taken, *Someone else reviews: review required* and *I work alone: review optional*, and the button waits for it. It can still be changed later from the project's menu. If adding a project and creating its repository become one step for a person naming themselves, the choice moves into *Add a project*, shown only then.

**The menu's order.** *Fill it from a checkout…* no longer stands first. It reads a checkout folder and files what it finds as a signed commit in the project's own repository, so it is for a person with a checkout they already have, and it comes after the repository exists. A person who adds repositories by address never needs it.

**What else reads that list, and follows.** The side bar's count of *My projects*, the rows of *My projects* themselves, and a machine's page, which lists the person's projects on that machine. *Put it on a machine…* stands on the Organization page's row with no such condition, and whether it can stand before the repository exists is read when this is built.

**What a project's page leaves out** falls away, as that page is reached only once the repository exists: "This project has not been opened yet", the review line "Porelo does not name the current review policy", and "Project repository: none named yet". A project page reached with an old link or a stale list still says the sentence above and goes back.

**An empty list's words.** "No repositories supplied." comes from `FilteredListSection`, which says "No <title> supplied." for every empty list. A list needs a way to say its own words; a project's *Repositories* says how to add one, and the word "supplied" is read for every list then.

## The same for a machine with no address yet

"Open the machine's page" on the Organization page lands under *My machines* on a page that is gone once the person leaves, since that list holds what this window reaches and no such machine is there. A machine with no address stands on the Organization page in the same way: "<machine> has no address yet."

**What a person who has just named a machine presses: *Prepare a machine…*.** Its dialog asks for the name, and the run files the real address, port and SSH host key on the machine's card itself. A machine still to be rented has no address anyone could enter. Today that button stands on the head of the lists and not on the machine's page, while that page offers *Change address and key…*, the wrong one to press first.

**So the row and the page show one step,** for its Machine Admin: *Prepare this machine…*, with the name filled in. Entering by hand stays as a quieter action for a machine already prepared elsewhere, and reads *Enter address and key…* while neither is there, with a dialog button to match; *Change address and key…* comes once there is something to change. Once it has an address, the row's menu says *Go to the machine*.

"No projects on this machine supplied." is the same empty list's phrase as above, and says what comes first: a project goes on a machine once the machine is prepared.

## Acceptance

- A project with no repository stands on the Organization page with the sentence, the button for its Project Admin and the waiting words for anyone else, and not under *My projects*. Seen to fail first.
- Its named Project Admin has a row in *Needs you* that goes straight to the dialog, and the row goes once the repository exists; an Organization Admin who is not the Project Admin has none.
- The button cannot be pressed before the review choice is made.
- Once it exists, the project appears under *My projects*, counted, and the row's menu says *Go to the project*.
- No word on these pages says "open" for it.
- A machine with no address shows its sentence and, for its Machine Admin, *Prepare this machine…* with its name filled in, on its Organization row and its page; no step needs a page that is gone on leaving.
- *Change address and key…* is not offered while neither is there.

## Decided while building

- **An older Porelo that does not say `opened` reads as before.** No project is said to lack a repository on its word.
- **A project page reached anyway** names who it waits for and goes back; the button stands on the Organization page and in *Needs you* only.
- **Someone naming themselves** answers about review in *Add a project*, and the one call adds and creates. Stopping halfway leaves the change's pending row with its refusal; put away, the project's row has its button.
- **A stale read of the organization** says nothing of a missing repository, in any of these places.
- **A machine with no address** has *Prepare this machine…* on its row and its page, with its name chosen in the dialog, and *Enter address and key…* in its row's menu and on its page. Its row's own tap still opens its page.
- **The empty list's words** are now "No <title> yet.", and a list can say its own.

## To be checked

- **The window's list does not read it yet.** Each project of `porelo org --json` carries `opened`, read from the organization's tree with no call per project, and snapshot builds have it, 0.5.0 not. It says a filed address, not a repository on the forge, so a run that stopped between the two reads as not opened and is finished by asking again with the same id. `stale` at the top of the answer still applies.
- *Needs you* is built from machines and this computer, and holds no row from the organization yet; a stale or unread organization must not say a repository is missing.
- *Fill it from a checkout…* before the repository exists: what it answers, and that an Organization Admin who is not the Project Admin is offered it.
