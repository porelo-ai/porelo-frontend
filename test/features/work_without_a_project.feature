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
