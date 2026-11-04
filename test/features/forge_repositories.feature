# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: A forge's repositories, its tokens, and what waits at a gate

    Background:
        Given a backend with work on it
        And the app is running

    # Found in use: with a token kept from before, the dialog came up and went away again.
    Scenario: with a token kept from before, the repositories are listed and the dialog stays
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        When I open my forges
        And I choose the forge {'GitHub'}
        Then it says {'GitHub'}
        And it says {'login alice'}
        And the forge's repository {'acme/api'} is listed

    # The forges are kept in one place: several of one kind, each named.
    Scenario: a second forge is set up beside the first, each host token kept under its own entry
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        And the forge also accepts the token {'ghp_work'}
        When I open my forges
        And I add the forge {'GitHub work'} at {'git.work.example.org'} with the token {'ghp_work'}
        Then the forges set up here are {'GitHub, GitHub work'}
        And the keychain keeps {'ghp_work'} for the forge entry {'GitHub work'}
        And the keychain keeps {'ghp_accepted'} for the forge entry {'GitHub'}
        And it says {'git.work.example.org · token chosen explicitly'}

    Scenario: with two forges set up, the repositories are shown once one is chosen
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the forges {'GitHub'} and {'GitHub work'} are set up, both reaching it
        When I open my forges
        Then it says {'Connect a forge'}
        And no token is asked for
        When I choose the forge {'GitHub work'}
        Then it says {'GitHub work'}
        And it says {'login alice'}
        And the forge's repository {'acme/api'} is listed

    Scenario: a forge is renamed and given a new token, through the terminal prompt
        Given the keychain here keeps the token {'ghp_accepted'} for the forge
        And the forge also accepts the token {'ghp_renewed'}
        When I open my forges
        And I change {'GitHub'} to be called {'GitHub private'} with the token {'ghp_renewed'}
        Then the forges set up here are {'GitHub private'}
        And the keychain keeps {'ghp_renewed'} for the forge entry {'GitHub private'}

    # Removing the local API token leaves machine vault tokens and forge access alone.
    Scenario: removing a forge leaves machine vaults and legacy keys alone
        Given the keychain here keeps the token {'ghp_accepted'} for the forge
        And the machine has the project {'checkout'} from {'git@github.com:acme/api.git'}
        And the forge holds the key {'porelo vm api/api'} at {'acme/api'} from a machine that is gone
        When I open my forges
        And I remove the forge {'GitHub'}
        Then it says {'Projects on your machines use it: acme/api'}
        When I press {'Remove it'}
        Then the forges set up here are {''}
        And the keychain here keeps no token

    # Typed in the terminal, kept in the system store, and then checked against the forge.
    Scenario: a token the forge accepts connects it, and is kept here
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I open my forges
        And I connect the forge with the token {'ghp_accepted'}
        Then it says {'GitHub'}
        And it says {'login alice'}
        And the keychain here keeps the token {'ghp_accepted'}
        And it does not say {'ghp_accepted'}

    Scenario: a stored token the forge refuses is said in its words
        When I open my forges
        And I connect the forge with the token {'ghp_wrong'}
        Then it says {'GitHub does not accept this token'}
        And the keychain here keeps the token {'ghp_wrong'}
        And the forge form takes no token

    # Push access lets the person commit the machine-signers change; administration is unnecessary.
    Scenario: every repository says whether it can be pushed to
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I open my forges
        And I connect the forge with the token {'ghp_accepted'}
        Then the forge's repository {'acme/api'} says {'can push'}
        And the forge's repository {'acme/web'} says {'can push'}

    # Its row says what it holds, rather than a menu that seems to do nothing.
    # Walk 10: a project.yml is written in its repository only, never from here.
    Scenario: a repository with no project.yml is said to be no Porelo project, and nothing is offered for it
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I open my forges
        And I connect the forge with the token {'ghp_accepted'}
        And I look at the forge's repository {'acme/api'}
        Then the forge's repository {'acme/api'} says {'no project.yml yet'}

    # GitHub lists every repository of the account, whatever the token was narrowed to (a
    # token for one organization listed another's). All are shown; narrowing asks about each one.
    # Which are projects already is asked of the forge for every repository, and said on its line.
    Scenario: a repository with a project.yml says so on its line
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} has a project.yml
        And {'acme/web'} has a project.yml
        When I open my forges
        And I connect the forge with the token {'ghp_accepted'}
        Then the forge's repository {'acme/api'} says {'has a project.yml'}
        And the forge's repository {'acme/web'} says {'has a project.yml'}
    Scenario: a kept token is said to be used while it is tried, not offered as a field to type into
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        And the forge answers only when told
        When I open my forges
        And I choose the forge {'GitHub'}
        Then it says {'token chosen explicitly'}
        And no token is asked for
        When the forge answers
        Then it says {'GitHub'}
        And it says {'login alice'}

    Scenario: the list narrows to what is searched for
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I open my forges
        And I connect the forge with the token {'ghp_accepted'}
        And I search the repositories for {'web'}
        Then the forge's repository {'acme/web'} is listed
        And the forge's repository {'acme/api'} is not listed

    Scenario: a repository says whether it is a project already
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} has a project.yml
        When I open my forges
        And I connect the forge with the token {'ghp_accepted'}
        And I look at the forge's repository {'acme/api'}
        And I look at the forge's repository {'acme/web'}
        Then the forge's repository {'acme/api'} says {'has a project.yml'}
        And the forge's repository {'acme/web'} says {'no project.yml yet'}

    Scenario: a kept token connects without typing, and forgetting it forgets it here
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        When I open my forges
        And I choose the forge {'GitHub'}
        Then it says {'GitHub'}
        And it says {'login alice'}
        When I forget the token here
        Then the keychain here keeps no token

    # Walk 8: "When I am done, I must be able to clear everything on the server very
    # simply." One action, one confirmation, and what was removed and what was left said.
    Scenario: a machine is cleared in one step and its signer is removed without deploy keys
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the machine has the project {'api'} from {'git@github.com:acme/api.git'}
        When I choose the command {'Clear this machine of everything Porelo put there…'}
        Then it says {'This goes, on'}
        When I press {'Clear it'}
        Then the machine was cleared {'everything'}, after a dry run
        And the forge holds no key of the machine at {'acme/api'} or {'acme/backend'}
        And no deploy key calls were made

    Scenario: a configuration change waiting at a machine's gate is reviewed, merged signed here, and cleared there
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the machine has the project {'api'} from {'git@github.com:acme/api.git'}
        And the machine's gate holds the change {'plan'} saying {'Add the internal mirror'}
        When I open my forges
        And I connect the forge with the token {'ghp_accepted'}
        And I look at the changes waiting at {'acme/api'}
        Then merging the change {'plan'} is not offered yet
        When I review the change {'plan'}
        Then it says {'+  sets: [internal-mirror]'}
        When I merge the change {'plan'} signed
        Then the change {'plan'} was merged here signed with {'SHA256:person'}
        And the machine was told {'plan'} landed on {'main'}
        And it says {'pushed to main, and cleared at'}

    Scenario: a merge the upstream does not hold yet is said in the machine's words, and stays listed
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the machine's gate holds the change {'plan'} saying {'Add the internal mirror'}
        And the upstream does not hold what is merged yet
        And the machine has the project {'api'} from {'git@github.com:acme/api.git'}
        When I open my forges
        And I connect the forge with the token {'ghp_accepted'}
        And I look at the changes waiting at {'acme/api'}
        And I review the change {'plan'}
        And I merge the change {'plan'} signed
        Then it says {'push the merge first'}
        And the change {'plan'} is still listed

    # Walk 10: the forges are a place of their own, after Machines, laid out as Projects is.
    Scenario: the forges are a place of their own, after the machines, each opened to its repositories
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        And the machine has the project {'checkout'} from {'git@github.com:acme/api.git'}
        Then the rail lists {'Machines, Forges, Projects'} in this order
        When I go to the forges
        Then it says {'Connect a forge'}
        When I choose the forge {'GitHub'}
        Then the forge's repository {'acme/api'} is listed
        And the repository {'acme/api'} is worked on on {'this machine'}

    # Walk 10: Default left Projects; a repository is put into it from its card.
    Scenario: a repository is worked on in the Default project from its card without deploy keys
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        When I go to the forges
        And I choose the forge {'GitHub'}
        And I look at the forge's repository {'acme/api'}
        And I choose {'default-add'} from the card of {'acme/api'}
        Then default holds {'api'} at {'https://github.com/acme/api.git'}
        And no deploy key calls were made
