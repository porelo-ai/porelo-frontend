# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: A project from a repository a person already has on a forge

    Background:
        Given a backend with work on it
        And the app is running

    # The way that needs nothing typed has a place of its own beside following, not only in the finder.
    Scenario: a project from a repository is on screen, beside following one
        Given I go to the work
        When I pick a project from one of my repositories
        Then the repositories are offered

    # Found in use: with a token kept from before, the dialog came up and went away again.
    Scenario: with a token kept from before, the repositories are listed and the dialog stays
        Given I go to the work
        And the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        When I pick a project from one of my repositories
        Then the repositories are offered
        And it says {'GitHub'}
        And it says {'as alice'}
        And the forge's repository {'acme/api'} is listed

    Scenario: following a project by hand points to picking one of the person's repositories
        Given I go to the work
        When I follow a repository
        And I pick one of my repositories instead
        Then the repositories are offered

    # The forges are kept in one place: several of one kind, each named.
    Scenario: a second forge is set up beside the first, each token kept under its own entry
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        And the forge also accepts the token {'ghp_work'}
        When I open my forges
        And I add the forge {'GitHub work'} at {'github.com'} with the token {'ghp_work'}
        Then the forges set up here are {'GitHub, GitHub work'}
        And the keychain keeps {'ghp_work'} for the forge entry {'GitHub work'}
        And the keychain keeps {'ghp_accepted'} for the forge entry {'GitHub'}
        And it says {'GitHub work is set up'}

    Scenario: with two forges set up, the repositories are shown once one is chosen
        Given I go to the work
        And the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the forges {'GitHub'} and {'GitHub work'} are set up, both reaching it
        When I pick a project from one of my repositories
        Then it says {'Add a forge'}
        And no token is asked for
        When I choose the forge {'GitHub work'}
        Then it says {'GitHub work'}
        And it says {'as alice'}
        And the forge's repository {'acme/api'} is listed

    Scenario: a forge is renamed and given a new token, which is kept only once it is accepted
        Given the keychain here keeps the token {'ghp_accepted'} for the forge
        And the forge also accepts the token {'ghp_renewed'}
        When I open my forges
        And I change {'GitHub'} to be called {'GitHub private'} with the token {'ghp_renewed'}
        Then the forges set up here are {'GitHub private'}
        And the keychain keeps {'ghp_renewed'} for the forge entry {'GitHub private'}

    # Removing touches nothing at the forge; what would be left without a way off is said first.
    Scenario: removing a forge that a followed project uses offers to take the machines' keys off first
        Given the keychain here keeps the token {'ghp_accepted'} for the forge
        And the machine follows the project {'checkout'} from {'git@github.com:acme/api.git'}
        And the forge holds the key {'porelo vm api/api'} at {'acme/api'} from a machine that is gone
        When I open my forges
        And I remove the forge {'GitHub'}
        Then it says {'Projects your machines follow use it: acme/api'}
        When I remove the machines' keys there first
        Then the forge holds no key titled {'porelo vm api/api'} at {'acme/api'}
        And the forges set up here are {''}
        And the keychain here keeps no token

    # Asked before the step, not refused after the person filled everything in.
    Scenario: a machine whose Porelo cannot be bound says so before anything is asked of it
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the machine's Porelo cannot work on a project from here yet
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I look at the forge's repository {'acme/api'}
        And I start working on {'acme/api'} on the machine
        Then it says {'runs a Porelo that cannot do this yet'}
        And working on it on the machine is not offered
        And nothing was asked of the machine to work on it

    Scenario: a project whose repository is on a forge not set up here says so in its menu
        Given I go to the work
        And the machine follows the project {'checkout'} from {'git@gitlab.example.org:acme/api.git'}
        And I select the project {'checkout'}
        When I open the command finder
        Then the command {'Its machines and keys at its forge'} is unavailable because {'gitlab.example.org, which is not set up here'}

    Scenario: a repository no forge holds is followed by its address from the same dialog
        Given I go to the work
        When I pick a project from one of my repositories
        And I follow by its address instead
        Then following a repository by hand is open

    # Typed once, kept in this computer's keychain, and only once the forge accepted it.
    Scenario: a token the forge accepts connects it, and is kept here
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        Then it says {'GitHub'}
        And it says {'as alice'}
        And the keychain here keeps the token {'ghp_accepted'}
        And it does not say {'ghp_accepted'}

    Scenario: a token the forge refuses is said in its words, and nothing is kept
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_wrong'}
        Then it says {'GitHub does not accept this token'}
        And the keychain here keeps no token
        And the token field hides what is typed

    # Binding a machine adds a deploy key, which only an admin may do: said on the row, not found out later.
    Scenario: every repository says whether a machine can be bound from here
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        Then the forge's repository {'acme/api'} says {'you are an admin'}
        And the forge's repository {'acme/web'} says {'not an admin: no machine can be given keys to it from here'}

    # Choosing one says what comes next under it, rather than a click that seems to do nothing.
    # Walk 10: a project.yml is written in its repository only, never from here.
    Scenario: a repository with no project.yml is said to be no Porelo project, and nothing is offered for it
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I look at the forge's repository {'acme/api'}
        Then what comes next for {'acme/api'} says {'It has no project.yml, so it is no Porelo project. Add one in the repository itself'}
        And binding is not offered for {'acme/api'}

    Scenario: a project the token may bind is offered to be bound, saying what that does
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} has a project.yml
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I look at the forge's repository {'acme/api'}
        Then what comes next for {'acme/api'} says {'gets keys of its own for it'}

    # The rights GitHub lists are the account's; a token narrowed to fewer is found out by asking.
    Scenario: a token that may not manage a repository's keys is said so, and binding is not offered
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} has a project.yml
        And the token may not manage the keys of {'acme/api'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        Then binding is not offered for {'acme/api'}
        And what comes next for {'acme/api'} says {'this token may not give a machine keys to it'}

    # GitHub lists every repository of the account, whatever the token was narrowed to (a
    # token for one organization listed another's). All are shown; narrowing asks about each one.
    # Which are projects already is asked of the forge for every repository, and said on its line.
    Scenario: a repository with a project.yml says so on its line, and is used as a project from there
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} has a project.yml
        And {'acme/web'} has a project.yml
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        Then the forge's repository {'acme/api'} says {'has a project.yml'}
        And the forge's repository {'acme/web'} says {'has a project.yml'}
        # Binding adds a key, which only an admin may: a project the person is no admin of is not used.
        And using {'acme/web'} as a project is not offered on its line
        When I use {'acme/api'} as a project
        Then binding the machine is offered

    Scenario: a project the token may not bind says so on its line, with the forge's reason, and offers no use
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} has a project.yml
        And the token may not manage the keys of {'acme/api'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I look at the forge's repository {'acme/api'}
        Then using {'acme/api'} as a project is not offered on its line
        And the forge's repository {'acme/api'} says {'this token may not give a machine keys to it'}
        And binding the machine is not offered
        And what comes next for {'acme/api'} says {'Resource not accessible by personal access token'}

    Scenario: every repository is listed, and narrowing to what the token may bind asks the forge
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        Then the forge's repository {'acme/api'} is listed
        And the forge's repository {'acme/web'} is listed
        And it says {'Can be slow'}
        And it does not say {'This token cannot set a machine up to work on any of them'}
        When I list only those the token may bind
        Then the forge's repository {'acme/api'} is listed
        And the forge's repository {'acme/web'} is not listed
        And it does not say {'This token cannot set a machine up to work on any of them'}

    Scenario: a token that may bind a machine to none of the repositories says what it needs
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the token may not manage the keys of {'acme/api'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        Then it does not say {'This token cannot set a machine up to work on any of them'}
        When I list only those the token may bind
        Then the forge's repository {'acme/api'} is not listed
        And it says {'This token cannot set a machine up to work on any of them'}

    Scenario: a kept token is said to be used while it is tried, not offered as a field to type into
        Given I go to the work
        And the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        And the forge answers only when told
        When I pick a project from one of my repositories
        Then it says {'set up on this computer'}
        And no token is asked for
        When the forge answers
        Then it says {'GitHub'}
        And it says {'as alice'}

    Scenario: the list narrows to what is searched for
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I search the repositories for {'web'}
        Then the forge's repository {'acme/web'} is listed
        And the forge's repository {'acme/api'} is not listed

    Scenario: a repository says whether it is a project already
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} has a project.yml
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I look at the forge's repository {'acme/api'}
        And I look at the forge's repository {'acme/web'}
        Then the forge's repository {'acme/api'} says {'has a project.yml'}
        And the forge's repository {'acme/web'} says {'no project.yml yet'}

    Scenario: a kept token connects without typing, and forgetting it forgets it here
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        When I choose the command {'A project from a repository you have'}
        Then it says {'GitHub'}
        And it says {'as alice'}
        When I forget the token here
        Then the keychain here keeps no token

    # Only public halves travel: each repository gets the machine's key, the machine pins the person's.
    Scenario: a machine is bound to a project, each repository given its key, and the machine pinned to the person
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then the forge holds {'porelo vm api/api'} at {'acme/api'}, read-only
        And the forge holds {'porelo vm api/backend'} at {'acme/backend'}, with write access
        And the machine followed {'api'} pinned to the person's key
        And it says {'accepts changes to the project signed with your key'}
        And machine-signers holds the machine's line, committed signed with {'SHA256:person'}
        And the machine never saw the forge's token

    # A key left at the forge for a machine that never followed would let it in all the same.
    Scenario: a binding that does not finish takes back the keys it registered
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the forge refuses a deploy key at {'acme/backend'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then it says {'refused a deploy key at acme/backend'}
        And it says {'Took porelo vm api/api back from acme/api, since the binding did not finish.'}
        And the forge holds no key at {'acme/api'}

    # Walk 10: a repository whose commits were not signed by the pinned key read as followed, and the
    # next call found no project. A refused first follow leaves nothing on the machine, and says why.
    Scenario: a follow the machine refuses ends the binding, says why, and takes the key back
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the next follow is refused as {'NOT_SIGNED_BY_PIN'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then it says {'did not follow api: NOT_SIGNED_BY_PIN. Nothing of it is on'}
        And it does not say {'follows api'}
        And it says {'Took porelo vm api/api back from acme/api, since the binding did not finish.'}
        And the forge holds no key at {'acme/backend'}

    Scenario: a key that cannot be taken back is said, to be removed by hand
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the forge refuses a deploy key at {'acme/backend'}
        And the forge refuses removing keys at {'acme/api'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then it says {'porelo vm api/api could not be taken back from acme/api'}
        And it says {'remove it there by hand'}

    # The person's keys are found at the forge, not chosen from what the agent holds, and all of them
    # are pinned, so a commit signed on any computer of theirs is accepted.
    Scenario: a machine is pinned to every signing key the forge lists for the person, asked for none
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the forge lists my signing keys {'Laptop'} and {'Desktop'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then the machine followed {'api'} pinned to every signing key at the forge
        And it says {'accepts changes to the project signed with any of your signing keys at GitHub'}

    # A fresh machine has never met github.com; GitHub publishes its own key over its API, so the
    # person trusts that one with one press rather than comparing fingerprints by eye.
    Scenario: a machine that never met the forge's host trusts the key the forge publishes, and is bound
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the machine has never met the host {'github.com'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then it says {'has never met github.com'}
        And it says {'GitHub publishes this key'}
        When I press {'Trust GitHub’s published key and go on'}
        Then the machine trusts {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'} for {'github.com'}, and nothing else
        And the machine followed {'api'} pinned to the person's key
        And it says {'accepts changes to the project signed with your key'}

    # Walk 8: "When I am done, I must be able to clear everything on the server very
    # simply." One action, one confirmation, and what was removed and what was left said.
    Scenario: a machine is cleared in one step: what goes is listed first, then its keys go at the forge
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        And I close the binding and the repositories
        And I choose the command {'Clear this machine of everything Porelo put there, and its keys at the forge…'}
        Then it says {'This goes, on'}
        And it says {'the deploy key porelo vm api/backend'}
        When I press {'Clear it'}
        Then the machine was cleared {'everything'}, after a dry run
        And the forge holds no key of the machine at {'acme/api'} or {'acme/backend'}
        And it says {'Removed porelo vm api/backend from acme/backend'}
        And machine-signers no longer holds the machine's line

    # Walk 8: a work repository still held a project.yml of its own from an earlier test, and nothing said so.
    Scenario: a work repository that is a project of its own is said so at the binding
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And {'acme/backend'} is a project of its own
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then it says {'acme/backend holds a project.yml of its own'}

    # A token whose rights stop a binding is changed where it stopped, and the binding goes on with it.
    Scenario: a token changed from a binding it stopped is the one the binding goes on with
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And only the token {'ghp_admin'} may add deploy keys
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then it says {'Administration: Read and write'}
        When I change the token of {'GitHub'} from the binding to {'ghp_admin'}
        Then it does not say {'Administration: Read and write'}
        When I go on with the binding
        Then the forge holds {'porelo vm api/api'} at {'acme/api'} once

    Scenario: binding twice registers nothing twice
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        And I bind it again
        Then the forge holds {'porelo vm api/api'} at {'acme/api'} once
        And it says {'is in machine-signers already'}

    Scenario: a work repository on another forge is said, not registered
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'lib'} at {'git@gitlab.com:acme/lib.git'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then it says {'lib is not on GitHub, so its key is not registered from here.'}

    Scenario: a repository without admin rights offers no binding
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        Then binding is not offered for {'acme/web'}

    # The forge's keys go first: they are what grants access.
    Scenario: removing a machine removes its keys at the forge and its line from machine-signers
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        And I remove the machine
        Then the forge holds no key of the machine at {'acme/api'} or {'acme/backend'}
        And machine-signers no longer holds the machine's line
        And it says {'no longer follows api'}
        And it says {'Removed porelo vm api/backend from acme/backend'}

    # Two keys stayed at GitHub after walk 8, and nothing on screen said which or why.
    Scenario: a key the forge will not remove is said as left, and the others are removed all the same
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        And the token may not remove deploy keys at {'acme/backend'}
        And I remove the machine
        Then it says {'Left porelo vm api/backend at acme/backend: GitHub refused it'}
        And it says {'Removed porelo vm api/api from acme/api'}
        And machine-signers no longer holds the machine's line

    # The trust anchor is compared, never taken on trust: a different pin is said, loudly.
    Scenario: a machine that pinned another key than the person's says so
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the machine pins {'SHA256:somebody-else'} when it follows
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then it says {'which is not your key SHA256:person. Do not go on until you know why.'}

    Scenario: work is started on a machine once it is bound, the project chosen
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        # The start form follows the binding by itself, what was pinned said under it.
        Then it says {'Start work in api'}
        And it says {'accepts changes to the project signed with your key'}
        And the project {'api'} is the one shown

    # A machine that is gone for good is removed from what grants it access all the same.
    Scenario: every Porelo key and signer is listed, and one no machine claims is removed from here
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the forge holds the key {'porelo old-box api/api'} at {'acme/api'} from a machine that is gone
        And the forge holds the key {'ci deploy'} at {'acme/api'} of somebody else
        And machine-signers names {'old-box'} as {'porelo@old-box ssh-ed25519 AAAAold'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I look at every Porelo key and signer of {'acme/api'}
        Then it says {'porelo old-box api/api at acme/api, read-only'}
        And it says {'old-box (porelo@old-box)'}
        And it does not say {'ci deploy'}
        When I remove the key {'porelo old-box api/api'} at {'acme/api'}
        And I remove the signer {'porelo@old-box'}
        Then the forge holds no key titled {'porelo old-box api/api'} at {'acme/api'}
        And machine-signers no longer names {'porelo@old-box'}, committed signed

    # The machine only reads the project's repository: its change is merged here, signed, and it is told.
    Scenario: a configuration change waiting at a machine's gate is reviewed, merged signed here, and cleared there
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the machine's gate holds the change {'plan'} saying {'Add the internal mirror'}
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        And I look at the changes waiting at the machine
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
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        And I look at the changes waiting at the machine
        And I review the change {'plan'}
        And I merge the change {'plan'} signed
        Then it says {'push the merge first'}
        And the change {'plan'} is still listed

    # Measured on Porelo 234: an applied follow does not repeat what it pinned; that is no warning.
    Scenario: a machine that does not repeat what it pinned is not said to have pinned another key
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And {'acme/api'} holds the project {'api'} with the work repository {'backend'} at {'git@github.com:acme/backend.git'}
        And the machine pins {''} when it follows
        When I choose the command {'A project from a repository you have'}
        And I connect the forge with the token {'ghp_accepted'}
        And I bind the machine to {'acme/api'}
        Then it says {'accepts changes to the project signed with your key'}
        And it does not say {'Do not go on'}

    # Walk 10: the forges are a place of their own, after Machines, laid out as Projects is.
    Scenario: the forges are a place of their own, after the machines, each opened to its repositories
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        And the machine follows the project {'checkout'} from {'git@github.com:acme/api.git'}
        Then the rail lists {'Machines, Forges, Projects'} in this order
        When I go to the forges
        Then it says {'Add a forge'}
        When I choose the forge {'GitHub'}
        Then the forge's repository {'acme/api'} is listed
        And the repository {'acme/api'} is worked on on {'this machine'}

    # Walk 10: Default left Projects; a repository is put into it from its card.
    Scenario: a repository is worked on without a project from its card, the machine given its key there
        Given the forge reaches {'acme/api'} as an admin, and {'acme/web'} without admin rights
        And the keychain here keeps the token {'ghp_accepted'} for the forge
        When I go to the forges
        And I choose the forge {'GitHub'}
        And I look at the forge's repository {'acme/api'}
        And I choose {'default-add'} from the card of {'acme/api'}
        Then default holds {'api'} at {'git@github.com:acme/api.git'}
        And the forge holds {'porelo vm default/api'} at {'acme/api'} once
