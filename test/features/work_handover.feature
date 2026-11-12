# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Reviewing what work pushed, and what it holds back

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    # Answered on the task itself. Nothing joins it to the gate: this container's
    # name is not the ref, and several containers over time share one.
    Scenario: work whose own commits are waiting for review says so on its detail
        When I select the work {'porelo-checkout-migrate'}
        And I open the selection
        Then it says {'its own work is waiting for review'}

    Scenario: work with nothing of its own waiting says that instead
        When I select the work {'porelo-checkout-shell'}
        And I open the selection
        Then it says {'nothing of its own is waiting'}

    Scenario: what a project pushed is readable file by file, without leaving the interface
        When I review what is waiting at the gate
        And I open the waiting push
        Then the review shows the file {'lib/money.dart'}
        And the review shows {'(value * 100).round()'}

    # To read it in an IDE: the fetch the machine names, copied, never run here.
    Scenario: a waiting push can be fetched into the person's own clone
        When I review what is waiting at the gate
        And I open the waiting push
        Then it says {'git fetch ssh://porelo@build-01/srv/checkout/.porelo/mirror refs/porelo/incoming/migrate:refs/remotes/porelo/migrate'}
        And it says {'safe mode'}

    Scenario: the diff leaves the interface in one action, for reading somewhere else
        When I review what is waiting at the gate
        And I open the waiting push
        And I copy the diff
        Then what was copied mentions {'lib/money.dart'}
        And what was copied mentions {'(value * 100).round()'}

    # Porelo names a waiting commit in full, and takes only the full id back (seven characters can be met
    # by another commit ground out while the person reads); the list shows it short.
    Scenario: a waiting push is listed by its short commit, and forwarded by its full one
        When I review what is waiting at the gate
        Then it says {'9a3c1f2'}
        And it does not say {'9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d'}

    Scenario: forwarding names the branch rather than guessing one
        When I review what is waiting at the gate
        And I open the waiting push
        And I forward it onto the branch {'fix-rounding'}
        Then it was forwarded onto {'fix-rounding'}
        And the forward named the commit reviewed {'9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d'}
        And the status line mentions {'was forwarded to fix-rounding'}
        And the projects were read again after it

    # A push made after the review went upstream unseen until Approve took the commit that was read.
    Scenario: a push that moved since it was reviewed is not forwarded, and that is said
        When I review what is waiting at the gate
        And I open the waiting push
        And the push moves before it is forwarded
        And I forward it onto the branch {'fix-rounding'}
        Then it says {'moved since you reviewed it: you read 9a3c1f2, and it holds b7e21d4 now'}
        And it says {'Nothing was forwarded'}

    Scenario: a branch that already holds earlier work is not forwarded onto, and another is named
        When I review what is waiting at the gate
        And I open the waiting push
        And the branch {'fix-rounding'} already holds earlier work
        And I forward it onto the branch {'fix-rounding'}
        Then it says {'fix-rounding already holds 4d2e9a1, from earlier work'}
        And it says {'Nothing was forwarded'}
        And it says {'onto another branch, such as fix-rounding-2'}

    # A real forward offered a deploy key ssh picked by itself, and the window showed git's raw line.
    Scenario: a forward refused for its key says which key, and not git's line
        When I review what is waiting at the gate
        And I open the waiting push
        And the forge refuses the push for its deploy key
        And I forward it onto the branch {'fix-rounding'}
        Then it says {'Nothing was forwarded'}
        And it says {'The forge knows the key as a deploy key'}
        And it says {'Key used: SHA256:deployKeyOfTheRepository, held by the ssh-agent.'}
        And it says {'SHA256:personalKeyOfThePerson'}
        And it says {'/home/alice/.ssh/id_rsa'}
        And it does not say {'exit code'}
        And it does not say {'--git-dir'}
        And no push went upstream

    Scenario: a forward with no key declared for its address says so
        When I review what is waiting at the gate
        And I open the waiting push
        And no ssh key is declared for the forge
        And I forward it onto the branch {'fix-rounding'}
        Then it says {'No ssh key is declared for ssh://git@github.com/acme/money.git'}
        And no push went upstream

    Scenario: a key tried alone is answered, and nothing is pushed or kept
        When I review what is waiting at the gate
        And I open the waiting push
        And the forge refuses the push for its deploy key
        And the forge takes the key {'SHA256:personalKeyOfThePerson'}
        And I forward it onto the branch {'fix-rounding'}
        And I try the key {'SHA256:personalKeyOfThePerson'}
        Then it says {'The forge would take the push with this key. Nothing was pushed.'}
        And the key {'SHA256:personalKeyOfThePerson'} was tried alone for {'refs/porelo/incoming/migrate:refs/heads/fix-rounding'}
        And no push went upstream
        And nothing was declared

    Scenario: keeping a key keeps it for that address alone, and forwards the reviewed commit again
        When I review what is waiting at the gate
        And I open the waiting push
        And the forge refuses the push for its deploy key
        And I forward it onto the branch {'fix-rounding'}
        And I keep the key {'SHA256:personalKeyOfThePerson'}
        Then the key {'SHA256:personalKeyOfThePerson'} was kept for {'ssh://git@github.com/acme/money.git'}, from {'AGENT'}
        And it was forwarded onto {'fix-rounding'}
        And the forward named the commit reviewed {'9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d'}

    Scenario: a key kept from a file is named by its path
        When I review what is waiting at the gate
        And I open the waiting push
        And the forge refuses the push for its deploy key
        And I forward it onto the branch {'fix-rounding'}
        And I keep the key {'/home/alice/.ssh/id_rsa'}
        Then the key {'/home/alice/.ssh/id_rsa'} was kept for {'ssh://git@github.com/acme/money.git'}, from {'FILE'}

    # The way through a refused key stayed on after the next forward was refused for another reason, and kept its old branch.
    Scenario: a forward refused for another reason after a refused key leaves no stale way through
        When I review what is waiting at the gate
        And I open the waiting push
        And the forge refuses the push for its deploy key
        And I forward it onto the branch {'fix-rounding'}
        And the branch {'other-branch'} already holds earlier work
        And I forward it onto the branch {'other-branch'}
        Then it says {'other-branch already holds 4d2e9a1'}
        And it does not say {'Choose the key to forward fix-rounding'}

    Scenario: a key file the machine cannot sign with is not offered to keep
        When I review what is waiting at the gate
        And I open the waiting push
        And the forge refuses the push for its deploy key
        And the account also has a key file locked by a passphrase {'/home/alice/.ssh/id_locked'}
        And I forward it onto the branch {'fix-rounding'}
        Then the key {'/home/alice/.ssh/id_locked'} cannot be kept

    Scenario: what only a terminal can do is shown ready, and nothing runs until it is started
        When I review what is waiting at the gate
        And I open the waiting push
        And the forge refuses the push for its deploy key
        And I forward it onto the branch {'fix-rounding'}
        And I open the terminal for the refused key
        Then it says {'porelo credentials keys'}
        And I do not start it
        And no terminal was opened

    # Return and the button are two ways to answer, and only the button refused an empty name once.
    Scenario: an empty branch is not an answer, however it is given
        When I review what is waiting at the gate
        And I open the waiting push
        And I press Return on the branch {'  '}
        Then no push went upstream

    Scenario: dropping the request leaves the work in the mirror
        When I review what is waiting at the gate
        And I open the waiting push
        And I drop the request
        Then the status line mentions {'still in the mirror'}
        And the status line mentions {'Its task was told.'}
        And nothing was forwarded

    # The task the push came from is told in its inbox, so its agent does not hand the same work over again.
    Scenario: dropping the request can say why, and its task is told those words
        When I review what is waiting at the gate
        And I open the waiting push
        And I drop the request, saying {'the rounding is still wrong'}
        Then the drop gave the reason {'the rounding is still wrong'}
        And the status line mentions {'Its task was told, with your words.'}

    Scenario: a push whose task is gone is dropped, and it says nobody was told
        Given the task the waiting push came from is gone
        When I review what is waiting at the gate
        And I open the waiting push
        And I drop the request
        Then the status line mentions {'nobody was told'}

    Scenario: cancelling the drop keeps the request
        When I review what is waiting at the gate
        And I open the waiting push
        And I start to drop the request and cancel
        Then nothing was dropped

    Scenario: a project with no file recorded offers no gate, and names the reason
        When I select the project {'unrecorded'}
        And I open the command finder
        Then the command {'Review what is waiting at the gate'} is offered as unavailable

    # A screen full of waiting pushes reads as a wall, and it is not one: work can go straight
    # upstream by hand. The guard against that is a pre-push hook installed per clone, on whichever
    # machine somebody pushes from — which is not this interface's to install and often not even the
    # machine it is talking to.
    Scenario: the gate says what it does not see, rather than reading as a wall
        When I review what is waiting at the gate
        Then it says {'Work can also be pushed straight upstream by hand'}
        And it says {'per clone, on the machine you push from'}

    # Withdrawn entirely, not reworded into a smaller feature: Porelo does not know
    # what instruction files are called, and cannot merge them, because how an agent combines
    # several is that agent's rule. A screen guessing a set of filenames would answer "no
    # instructions" with confidence for a task that had them.
    Scenario: where somebody asks what an agent was told, the answer is not here
        When I select the work {'porelo-checkout-shell'}
        And I open the selection
        Then it says {'in the repository — nothing here has a view of them'}

    # `WorkHeld` is asked for one task when it is opened, never while drawing a
    # list: it runs git inside the container, which on a list this interface redraws would be a call
    # per row.
    Scenario: what a running task holds that never reached the gate is on its detail
        Given the work holds {2} unpushed commits and {3} changed files
        When I select the work {'porelo-checkout-shell'}
        And I open the selection
        Then it says {'holds 2 unpushed commits and 3 changed files'}

    # Holding nothing and nobody having looked are different answers, and only one of them makes it
    # safe to remove a task without asking.
    Scenario: holding nothing is said as holding nothing
        Given the work holds {0} unpushed commits and {0} changed files
        When I select the work {'porelo-checkout-shell'}
        And I open the selection
        Then it says {'holds nothing that never reached the gate'}

    Scenario: a task nobody could look inside says that, not that it holds nothing
        Given nobody could look inside the work
        When I select the work {'porelo-checkout-shell'}
        And I open the selection
        Then it says {'nothing recorded what it held'}
        And it says {'killed, rebooted, or stopped by an older Porelo'}

    # "Holds" and "held" are different sentences: a stopped task's workspace is inside a container
    # that is no longer up, so the only source is what the stop wrote down.
    Scenario: a stopped task says what it held when it stopped, and when that was
        Given the work held {4} unpushed commits when it stopped
        When I select the work {'porelo-checkout-shell'}
        And I open the selection
        Then it says {'held 4 unpushed commits when it stopped'}
        And it says {'minutes ago'}

    # A wrong name is a refusal, never an unreadable answer — merging them would make a client's
    # mistake arrive as a legitimate reading.
    Scenario: a name the machine does not know is refused rather than read as unreadable
        Given the machine knows no such task
        When I select the work {'porelo-checkout-shell'}
        And I open the selection
        Then it says {'does not know a task called'}

    # Every repository a project names has a gate of its own. Work a task did in one that
    # is not the project's own waits there — and asking only the project's own would never show it.
    Scenario: what waits in every repository is shown, and each push is decided where it waits
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        And {'Retry a declined card once'} waits in the repository {'payments-api'}
        When I review what is waiting at the gate
        Then it says {'Round to the nearest penny, not away from zero'}
        And it says {'Retry a declined card once'}
        And it says {'in payments-api'}
        When I open the waiting push {'Retry a declined card once'}
        Then it was reviewed in the repository {'payments-api'}
        When I forward it onto the branch {'retry-once'}
        Then it was forwarded from the repository {'payments-api'}

    Scenario: a repository whose gate cannot be read is named, and does not hide the others
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        And the gate of the repository {'payments-api'} cannot be read
        When I review what is waiting at the gate
        Then it says {'Round to the nearest penny, not away from zero'}
        And it says {'payments-api could not be read'}

    # A Porelo older than repositories per project names no repositories and knows no repository field.
    Scenario: a machine that names no repositories is asked about none
        When I review what is waiting at the gate
        And I open the waiting push
        And I forward it onto the branch {'fix-rounding'}
        Then the gate was asked about no repository

    Scenario: work names the repository it works in on its detail
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        And the work {'porelo-checkout-migrate'} works in the repository {'payments-api'}
        When I select the work {'porelo-checkout-migrate'}
        And I open the selection
        Then it says {'payments-api'}

    # The machine ranks what a push changes. What is dangerous by kind is
    # named first however small, the volume that is almost never a finding comes last and is never
    # hidden, and the order and the kinds are the machine's.
    Scenario: a push is reviewed in the order that matters, dangerous by kind first and volume last
        Given the machine ranks the waiting push with a CI definition, the change and a generated file
        When I review what is waiting at the gate
        And I open the waiting push
        Then the review lists {'.github/workflows/ci.yml, lib/money.dart, lib/money.g.dart'} in that order
        And the file {'.github/workflows/ci.yml'} is marked {'dangerous by kind'}
        And it says {'a CI definition, which runs with the credentials of CI'}
        And the file {'lib/money.g.dart'} is under what is almost never a finding
        And it says {'detects nothing: no file here is judged safe or injected'}

    # A real test showed three changed lines as +1042 -1043: the commit turned a CRLF file into LF.
    Scenario: a change mostly of line endings says so, with the real count beside the raw one
        Given the machine counts a CRLF to LF file of three real lines {'lib/legacy.dart'}
        When I review what is waiting at the gate
        And I open the waiting push
        Then it says {'Mostly line endings: +1 −2 without them, +1042 −1043 with them.'}
        And it says {'The diff below holds every such line'}

    Scenario: a change that is not of line endings reads as before
        Given the machine ranks the waiting push with a CI definition, the change and a generated file
        When I review what is waiting at the gate
        And I open the waiting push
        Then it does not say {'line endings'}

    Scenario: the diff can be read without line endings, and says it leaves them out
        Given the machine counts a CRLF to LF file of three real lines {'lib/legacy.dart'}
        When I review what is waiting at the gate
        And I open the waiting push
        And I show the diff without line endings
        Then the review was asked without line endings
        And it says {'The diff below leaves out what changed at line ends'}

    # A machine older than the switch refuses a parameter it does not know, and the whole review with it.
    Scenario: a machine that cannot leave line endings out is never asked to, and says the diff holds them
        Given the machine counts a CRLF to LF file of three real lines {'lib/legacy.dart'}
        And the machine cannot leave line endings out of a review
        When I review what is waiting at the gate
        And I open the waiting push
        Then it says {'this machine cannot leave them out'}
        And no review was asked without line endings

    # What the task was asked is kept apart from what it touched, and never compared with it.
    Scenario: what the task was asked is shown apart from what it touched
        Given the machine ranks the waiting push with a CI definition, the change and a generated file
        And the task that pushed was asked {'Round money to the nearest penny'}
        When I review what is waiting at the gate
        And I open the waiting push
        Then the review says it was asked {'Round money to the nearest penny'}
        And it does not say {'not asked for'}

    Scenario: a task started without an instruction is said to have had none
        Given the machine ranks the waiting push with a CI definition, the change and a generated file
        And the task that pushed was asked nothing
        When I review what is waiting at the gate
        And I open the waiting push
        Then it says {'It was started without an instruction.'}

    Scenario: a task gone from the machine is said to leave what it was asked unknown
        Given the machine ranks the waiting push with a CI definition, the change and a generated file
        When I review what is waiting at the gate
        And I open the waiting push
        Then it says {'what it was asked is not known here'}

    # Who wrote a push and its trailer are what says whether an agent made it; what the machine does not
    # report is said, never left out, and a check that cannot be made is never shown as passed.
    Scenario: the review names the commit, and says who wrote it and its trailer are not reported
        When I review what is waiting at the gate
        And I open the waiting push
        Then the review says {'Commit'} is {'9a3c1f2e4b5d6a7c8e9f0a1b2c3d4e5f6a7b8c9d'}
        And the review says {'Author'} is {'not reported by the machine'}
        And the review says {'Committer'} is {'not reported by the machine'}
        And the review says {'Trailer'} is {'not reported by the machine'}
        And the review says {'Trailer'} is {'cannot be checked here'}
        And the trailer check reads {'unknown'}

    # The check is made on the lines the machine reports: exactly one Assisted-by, and no Co-Authored-By.
    Scenario: a commit that names a co-author is shown as wrong, never as checked
        Given the machine names the commit as written by {'An Agent'} with the trailers {'Assisted-by: Claude Code claude-opus-5-5'} and {'Co-Authored-By: Claude'}
        When I review what is waiting at the gate
        And I open the waiting push
        Then the review says {'Author'} is {'An Agent'}
        And the review says {'Trailer'} is {'Co-Authored-By: Claude'}
        And the trailer check reads {'wrong'}

    Scenario: a commit that names two agents is shown as wrong
        Given the machine names the commit as written by {'An Agent'} with the trailers {'Assisted-by: Claude Code claude-opus-5-5'} and {'Assisted-by: Codex'}
        When I review what is waiting at the gate
        And I open the waiting push
        Then the trailer check reads {'wrong'}

    Scenario: a commit with one Assisted-by and no co-author is shown as checked
        Given the machine names the commit as written by {'An Agent'} with the trailers {'Assisted-by: Claude Code claude-opus-5-5'} and {'Signed-off-by: A Person'}
        When I review what is waiting at the gate
        And I open the waiting push
        Then the review says {'Committer'} is {'A Person'}
        And the trailer check reads {'passed'}

    # A long name or trailer wraps on a phone, never cut off or spilled past the card.
    Scenario: on a narrow window who made the commit and its trailer stay whole
        Given the machine names the commit as written by {'An Agent With A Rather Long Name From The Build Farm'} with the trailers {'Assisted-by: Claude Code claude-opus-5-5 running in the container porelo-checkout-migrate-1'} and {'Co-Authored-By: Claude'}
        When the window is {390} pixels wide
        And I review what is waiting at the gate
        And I open the waiting push
        Then the review says {'Author'} is {'An Agent With A Rather Long Name From The Build Farm <agent@example.org>'}
        And the review says {'Trailer'} is {'Assisted-by: Claude Code claude-opus-5-5 running in the container porelo-checkout-migrate-1'}
        And the trailer check reads {'wrong'}

    # A machine that reports the head commit on the waiting push, and no commits in the review.
    Scenario: the makers named on the waiting push are checked where the review lists none
        Given the waiting push names its author {'An Agent'} and the trailers {'Assisted-by: Claude Code claude-opus-5-5'} and {'Co-Authored-By: Claude'}
        When I review what is waiting at the gate
        And I open the waiting push
        Then the review says {'Author'} is {'An Agent'}
        And the review says {'Committer'} is {'not reported by the machine'}
        And the trailer check reads {'wrong'}

    # A Porelo older than the ranked review answers no files: the review is what it was before.
    Scenario: a machine that does not rank the review shows it as before
        When I review what is waiting at the gate
        And I open the waiting push
        Then the review shows the file {'lib/money.dart'}
        And it does not say {'What the task was asked'}

    # Read in the open: the list said nothing was waiting while it was still asked.
    Scenario: while the machine is asked, the gate says what it is reading
        Given the machine is slow to answer
        When I review what is waiting at the gate
        Then it shows that it is reading {'the gate of checkout'}
        And it does not say {'Nothing is waiting'}
        When the machine has answered
        Then it no longer shows that it is reading
        And it says {'9a3c1f2'}

    Scenario: a push being opened says what is read, then what it changes
        When I review what is waiting at the gate
        And the machine is slow to answer
        And I open the waiting push
        Then it shows that it is reading {'what this push changes'}
        When the machine has answered
        Then it no longer shows that it is reading
        And the review shows the file {'lib/money.dart'}

    # One view serves every project: the one asked before is not shown under the next one's name.
    Scenario: another project's waiting pushes are not shown while its own gate is read
        When I review what is waiting at the gate
        And the machine has the project {'api'} from {'git@github.com:acme/api.git'}
        And I select the project {'api'}
        And the machine is slow to answer
        And I choose the command {'Review what is waiting at the gate'}
        Then it does not say {'9a3c1f2'}
        And it shows that it is reading {'the gate of api'}
        When the machine has answered
        Then it no longer shows that it is reading
