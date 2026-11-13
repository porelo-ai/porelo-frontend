# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Work on a repository without writing a project first

    Background:
        Given a backend with work on it
        And the machine has the project default
        And the app is running
        And I go to the work

    # default is every machine's, kept by Porelo, and nobody configures it.
    Scenario: default is the project shown first, and cannot be removed
        Then the first project on the machine is {'default'}
        When I select the project {'default'}
        And I open the command finder
        Then the command {'Remove this project'} is unavailable because {'the Default project is always there'}

    # One way: a repository is named, typed or picked at a forge beside the
    # field, and work starts on it; it goes into default on the way.
    Scenario: work in default starts on a repository named by its address, which goes into default on the way
        When I select the project {'default'}
        And I press the start tile
        Then it says {'which cannot be changed'}
        And it says {'Approved work goes to the repository’s origin'}
        When I start work in default on {'git@example.org:acme/tools.git'}
        Then default holds {'tools'} at {'git@example.org:acme/tools.git'}
        And the repository {'tools'} is chosen

    Scenario: a repository worked on before in default is started on again without naming it
        Given default holds {'tools'} at {'git@example.org:acme/tools.git'} already
        When I select the project {'default'}
        And I start work in this project
        And I start work in default on the one called {'tools'}
        Then the repository {'tools'} is chosen
        And nothing was put into default again

    # Harm: a repository default holds cannot be worked on, as the first was taken for its own.
    Scenario: default offers every repository it holds, and the one started on is chosen
        Given default holds {'utils4j'} at {'git@example.org:acme/utils4j.git'} already
        And default holds {'units4j'} at {'git@example.org:acme/units4j.git'} already
        When I select the project {'default'}
        And I start work in this project
        And I start work in default on the one called {'utils4j'}
        Then the repository {'utils4j'} is chosen
        And the repository {'units4j'} is offered to start in

    # Harm: adding and removing a repository must not change access at its forge.
    Scenario: a repository picked at a forge fills its https address without deploy keys
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        When I select the project {'default'}
        And I start work in this project
        And I pick {'acme/api'} at the forge for default
        Then the address for default reads {'https://github.com/acme/api.git'}
        When I start work on it from default
        Then default holds {'api'} at {'https://github.com/acme/api.git'}
        And no deploy key calls were made
        When I put the start away
        # Removing the repository leaves its forge access alone.
        When I choose the command {'Repositories of the Default project'}
        And I take {'api'} out of default
        Then the forge holds no key titled {'porelo vm default/api'} at {'acme/api'}

    # Opened from its row, as a person new to Porelo opens it: what it is, and the way to its repositories.
    Scenario: default opened from its row says what it is and offers its repositories, and nothing it lacks
        When I select the project {'default'}
        Then the project header does not say {'not on this machine'}
        And the project header does not say {'environment not prepared'}
        And the project header says {'worked on with Porelo’s own settings'}
        And the start tile says {'Start work'}

    # Harm: the repositories default holds are nowhere on its page, so a person cannot see what it holds.
    Scenario: default's page lists every repository it holds
        Given default holds {'utils4j'} at {'git@example.org:acme/utils4j.git'} already
        And default holds {'units4j'} at {'git@example.org:acme/units4j.git'} already
        And default holds {'foo-2'} at {'git@example.org:acme/foo-2.git'} already
        When I select the project {'default'}
        Then the project's repositories are {'utils4j, units4j, foo-2'}

    # Harm: default's page opened from its machine lists other rows than the same page opened from its row, as an older
    # Porelo's row named default.
    Scenario: default's page opened from its machine lists every repository it holds, and no row named default
        Given default holds {'default'} at {'git@example.org:acme/default.git'} already
        And default holds {'utils4j'} at {'git@example.org:acme/utils4j.git'} already
        And default holds {'units4j'} at {'git@example.org:acme/units4j.git'} already
        And default holds {'foo-2'} at {'git@example.org:acme/foo-2.git'} already
        When I open {'default'} from the projects of this machine
        Then the project's repositories are {'utils4j, units4j, foo-2'}

    # Harm: an older Porelo's row named default shows as a repository default holds.
    Scenario: default holding nothing but an older Porelo's row named default lists no repositories
        Given default holds {'default'} at {'git@example.org:acme/default.git'} already
        When I select the project {'default'}
        Then the project lists no repositories

    # Harm: a repository of default says nothing of where it is, so a person cannot tell where its work goes.
    Scenario: each repository on default's page says where it is
        Given default holds {'utils4j'} from the checkout {'/work/utils4j'} whose remote is {'git@example.org:acme/utils4j.git'}
        And default holds {'foo-2'} from the remote {'git@example.org:acme/foo-2.git'}
        When I select the project {'default'}
        Then the repository {'utils4j'} says {'From the checkout /work/utils4j'}
        And the repository {'foo-2'} says {'From git@example.org:acme/foo-2.git, and back there'}

    # Harm: a repository taken out of default from its row stays, or the deploy key the machine forgot goes unsaid.
    Scenario: a repository is taken out of default from its row on default's page
        Given default holds {'utils4j'} from the checkout {'/work/utils4j'} whose remote is {'git@example.org:acme/utils4j.git'}
        And default holds {'foo-2'} from the remote {'git@example.org:acme/foo-2.git'}
        And the machine keeps the deploy key {'porelo vm default/foo-2'} for {'foo-2'} in default
        When I select the project {'default'}
        And I take {'foo-2'} out of default from its row
        Then default no longer holds {'foo-2'}
        And the project's repositories are {'utils4j'}
        And it says {'foo-2 is out of default. Its mirror, and anything waiting in it, stay'}
        And it says {'porelo vm default/foo-2'}

    # Harm: a repository a task of default works on is taken out from under the task.
    Scenario: a repository a task of default works on stays in default when taken out from its row
        Given default holds {'foo-2'} from the remote {'git@example.org:acme/foo-2.git'}
        And the task {'porelo-default-fix'} of default works on {'foo-2'}
        When I select the project {'default'}
        And I take {'foo-2'} out of default from its row
        Then default still holds {'foo-2'}
        And it says {'Tasks of default still work on foo-2: porelo-default-fix'}
        And the project's repositories are {'foo-2'}

    # Harm: a second take-out while the first runs is asked too, and its "not in default any more" replaces the first
    # one's words and the deploy key to remove.
    Scenario: a repository of default is taken out once, however often its row is asked while it runs
        Given default holds {'foo-2'} from the remote {'git@example.org:acme/foo-2.git'}
        And the machine keeps the deploy key {'porelo vm default/foo-2'} for {'foo-2'} in default
        When I select the project {'default'}
        And the machine holds back its answer to taking a repository out of default
        And I take {'foo-2'} out of default from its row
        And I take {'foo-2'} out of default from its row
        And the machine answers the taking out
        Then the machine was asked to take {'foo-2'} out of default once
        And it says {'porelo vm default/foo-2'}
        And it does not say {'was not in default any more'}

    # Harm: a failed read of what default holds is swallowed, and its rows say less with no word why.
    Scenario: default's page says when the machine did not say what default holds
        Given default holds {'foo-2'} from the remote {'git@example.org:acme/foo-2.git'}
        And the machine cannot say what default holds
        When I select the project {'default'}
        Then it says {'did not say what default holds'}
        And the repository {'foo-2'} says {'git@example.org:acme/foo-2.git'}

    # Harm: the dialog takes a repository out from under a task of default that the page would refuse.
    Scenario: the Default dialog refuses a repository a task of default works on, as the page does
        Given default holds {'foo-2'} from the remote {'git@example.org:acme/foo-2.git'}
        And the task {'porelo-default-fix'} of default works on {'foo-2'}
        When I select the project {'default'}
        And I choose the command {'Repositories of the Default project'}
        And I take {'foo-2'} out of default
        Then default still holds {'foo-2'}
        And it says {'Tasks of default still work on foo-2: porelo-default-fix'}

    # A project that names the repository takes it over for new tasks.
    Scenario: a repository a project names too is offered to be taken out of default
        Given default holds {'api'} at {'https://github.com/acme/api.git'}, named by {'payments'} too
        When I select the project {'default'}
        And I choose the command {'Repositories of the Default project'}
        Then it says {'payments names it too: its next task starts there'}
        When I take {'api'} out of default
        Then default no longer holds {'api'}
        And it says {'Its mirror, and anything waiting in it, stay'}

    Scenario: only the Default project holds such repositories
        When I select the project {'checkout'}
        And I open the command finder
        Then the command {'Repositories of the Default project'} is unavailable because {'only the Default project holds such repositories'}

    # Approved work in the Default project goes to its repository's origin, never to a project's upstream.
    Scenario: work waiting in default is forwarded to its origin
        When I select the project {'default'}
        And I review what is waiting at the gate
        And I open the waiting push
        Then it says {'Forward it to its origin'}
        When I start forwarding it to its origin
        Then the forwarding asks {'Forward it to its origin'}

    # Each machine owns a permanent default, even before its daemon supplies a list.
    Scenario: work in the Default project is listed on its machine
        When I go to the place {'projects'}
        Then it says {'Default'}
        And the projects page lists {'checkout'} on {'this machine'}

    # A machine forgotten while its question is open is asked nothing more, and nothing starts on it.
    Scenario: a first task's question answered after its machine was forgotten writes nothing and starts nothing
        Given the first task on {'tools'} in default asks before it starts
        When I watch another machine called {'elsewhere'}
        And I go to the work
        And I select the project {'default'}
        And I press the start tile
        And I start work in default on {'git@example.org:acme/tools.git'}
        And I call it {'tools-work'}
        And I start it
        And the machine the start was pressed on is forgotten
        And I agree to the first task
        Then no first task was agreed to on any machine
        And nothing was started

    # Said once: the dialog said "Asking the machine" twice while it read what default holds.
    Scenario: while the machine is asked, default says once what it is reading
        Given default holds {'tools'} at {'git@example.org:acme/tools.git'} already
        When I select the project {'default'}
        And the machine is slow to answer
        And I press the start tile
        Then it shows that it is reading {'which repositories default holds'}
        And it does not say {'Any failure will appear here'}
        When the machine has answered
        Then it no longer shows that it is reading
        And it says {'git@example.org:acme/tools.git'}
