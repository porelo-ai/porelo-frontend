# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Where a repository's work comes from and goes, and catching up

    # One source per repository, used both ways. Started in a checkout, the checkout is the source
    # and approved work comes back into it; added by address, the remote is. A person reads which, and
    # brings a running task up to its source without stopping it.
    Background:
        Given a backend with work on it
        And the machine has the project default
        And the app is running
        And I go to the work

    Scenario: a repository started in a checkout says its work comes from it and goes back there
        Given default holds {'app'} from the checkout {'/home/somebody/work/app'} whose remote is {'git@example.org:app.git'}
        When I select the project {'default'}
        And I choose the command {'Repositories worked on without a project'}
        Then it says {'From the checkout /home/somebody/work/app, and back into it as porelo/<task>'}
        And it says {'its remote git@example.org:app.git is yours to pull and push'}

    Scenario: a repository added by its address says its work comes from that remote and goes there
        Given default holds {'tools'} from the remote {'git@example.org:acme/tools.git'}
        When I select the project {'default'}
        And I choose the command {'Repositories worked on without a project'}
        Then it says {'From git@example.org:acme/tools.git, and back there'}

    Scenario: a machine older than one source shows the address as before
        Given default holds {'tools'} at {'git@example.org:acme/tools.git'} already
        When I select the project {'default'}
        And I choose the command {'Repositories worked on without a project'}
        Then it says {'git@example.org:acme/tools.git'}
        And it does not say {'and back there'}

    Scenario: a running task is brought up to its source, and its agent is told
        Given a refresh moves {'main'} to {'111df4193e7e0011'}
        When I select the project {'checkout'}
        And I select the work {'porelo-checkout-shell'}
        And I choose the command {'Bring it up to its source'}
        Then the machine was asked to refresh the task {'porelo-checkout-shell'}
        And the status line mentions {'main moved to 111df4193e7e; its agent was told, and git fetch porelo brings it'}

    Scenario: a task without a gate says there is nothing to bring up, rather than nothing
        Given a refresh answers {'NOT_GATED'}
        When I select the project {'checkout'}
        And I select the work {'porelo-checkout-shell'}
        And I choose the command {'Bring it up to its source'}
        Then the status line mentions {'has no gate, so there is nothing here to bring up to its source'}
        And the status line mentions {'started without one, or it is offline'}

    Scenario: a refresh that failed says why, in the machine's words
        Given a refresh answers {'FAILED'} because {'the checkout /home/somebody/work/app is gone'}
        When I select the project {'checkout'}
        And I select the work {'porelo-checkout-shell'}
        And I choose the command {'Bring it up to its source'}
        Then the status line mentions {'could not be brought up to its source: the checkout /home/somebody/work/app is gone'}
