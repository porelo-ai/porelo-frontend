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

    # A Porelo older than the ranked review answers no files: the review is what it was before.
    Scenario: a machine that does not rank the review shows it as before
        When I review what is waiting at the gate
        And I open the waiting push
        Then the review shows the file {'lib/money.dart'}
        And it does not say {'What the task was asked'}
