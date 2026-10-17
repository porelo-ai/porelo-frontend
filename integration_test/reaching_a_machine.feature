# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/e2e.sh against a real machine.
Feature: Reaching a real machine, reading it, and following a project

    Background:
        Given the interface is running

    # What the machine says about itself is read the first time it is gone to and answers, so a
    # machine that cannot run a task is said so before the first start.
    Scenario: a machine added with a forward raised here is reached
        When I watch the test machine through a forward raised here
        Then the interface says what the test machine needs to run work
        And the test machine is answering

    Scenario: every reply the interface reads can be read from the real daemon
        Given the test machine is being watched
        Then every reply it gives can be read

    Scenario: a machine is tried from the dialog before it is watched
        When I try the test machine from the dialog
        Then the trial says {'Reached Porelo'}
        And no forward raised for the trial is left
        And I put the dialog away

    # The forward comes up either way; only connecting through it finds the far end empty. The socket
    # sits in the login's own runtime directory, so nothing but the daemon is missing.
    Scenario: a socket nobody serves on the test machine is found by trying it
        When I try the test machine from the dialog with a socket beside its own that nobody serves
        Then the trial says {'nothing answers at'}
        And the trial says {'none.sock on that machine'}
        And no forward raised for the trial is left
        And I put the dialog away

    # ssh reports a wrong uid in the same words as a missing daemon, so the machine is asked which uid
    # the login has. uid 0 is never the account the test logs in as.
    Scenario: a socket in another user's runtime directory on the test machine is named as that
        When I try the test machine from the dialog with the socket {'/run/user/0/porelo/none.sock'}
        Then the trial says {'runtime directory (uid 0)'}
        And no forward raised for the trial is left
        And I put the dialog away

    # The whole way a project now comes to a machine, against the daemon rather than a fake: a
    # repository on that machine, followed through the dialog, read back with everything the
    # interface draws from it, and then no longer followed. In this file rather than one of its own:
    # each file launches the interface again, and a second launch joins the first and exits.
    Scenario: a repository followed through the dialog becomes a project, and stops being one
        Given the test machine is being watched
        And the test machine has a project repository {'e2e-follow'}
        When I follow it from the interface, unverified
        Then the interface says it is following it
        And the machine lists {'e2e-follow'} as followed unverified, with its repositories and their limits
        When I stop following {'e2e-follow'} from the interface
        Then the machine no longer lists {'e2e-follow'}

    # The wizard's check is the real daemon's dry run: it answers, and writes nothing. Storing a token
    # is typed at a terminal on the machine, which is a person's — so the run leaves before adding.
    Scenario: a token is checked by the real machine, and leaving writes nothing
        Given the test machine is being watched
        When I check a token for {'https://e2e.invalid/'} in the wizard, and leave it
        Then the wizard's check was answered by the machine
        And the machine no longer lists the connection {'https://e2e.invalid/'}

    # A key the machine already has is picked from what the machine lists, and declared where it lies.
    Scenario: a key the machine has is picked from its list and declared where it lies
        Given the test machine is being watched
        And the test machine has an ssh key of its own {'id_e2e'}
        When I declare the machine's own key for {'ssh://e2e.invalid/'} from the interface
        Then the machine lists the connection {'ssh://e2e.invalid/'} as the key it has
        When I forget the connection {'ssh://e2e.invalid/'} from the interface
        Then the interface says what still holds its value
        And the machine no longer lists the connection {'ssh://e2e.invalid/'}

    # A key the machine already has is copied into the vault by the machine, from its own disk: the
    # interface runs the command the machine names, and nothing of the key passes through here.
    Scenario: a key the machine has is copied into the vault by the machine
        Given the test machine is being watched
        And the test machine has an ssh key of its own {'id_e2e'}
        And the test machine has an open vault
        When I copy the machine's own key into the vault for {'ssh://e2e-vault.invalid/'} from the interface
        Then the machine lists the connection {'ssh://e2e-vault.invalid/'} as a key in its vault
        When I forget the connection {'ssh://e2e-vault.invalid/'} from the interface
        Then the machine no longer lists the connection {'ssh://e2e-vault.invalid/'}
        And the vault entry of that key is removed again

    # An unknown host is a question for a person: its keys are shown, one is chosen and trusted, and
    # the follow is made again. The project itself needs a credential this account does not have, so
    # what is measured is that the host key stops being the answer.
    Scenario: a host never met is trusted from the follow, by the key its owner publishes
        Given the test machine is being watched
        And the test machine has never met {'github.com'}
        And the test machine has an ssh key of its own {'id_e2e'}
        And the test machine connects to {'ssh://github.com/'} with its own key
        When I follow {'git@github.com:porelo-ai/porelo-project.git'} as {'e2e-hostkey'} from the interface, unverified
        Then the interface shows the keys of {'github.com'}, with {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'}
        When I trust {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'} from the interface
        Then the machine knows {'github.com'} by the key {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'}
        And the machine no longer lists {'e2e-hostkey'}
        And the connection {'ssh://github.com/'} is forgotten again


    # The mistakes the single dialog let through, each stopped by the real machine's dry run before
    # anything is written. Back keeps what was described, and leaving writes nothing.
    Scenario: an ssh key for an https address is refused by the real check, and cannot be added
        Given the test machine is being watched
        And the test machine has an ssh key of its own {'id_e2e'}
        When I check the machine's own key for {'https://e2e-https.invalid/'} in the wizard
        Then the machine says it would not work, and it cannot be added
        When I leave the wizard
        Then the machine no longer lists the connection {'https://e2e-https.invalid/'}

    Scenario: a variable the machine does not have is refused by the real check, and back keeps it
        Given the test machine is being watched
        When I check the variable {'E2E_NOT_SET'} as a token for {'https://e2e-var.invalid/'} in the wizard
        Then the machine says it would not work, and it cannot be added
        When I go back, and the variable {'E2E_NOT_SET'} is still there
        And I leave the wizard
        Then the machine no longer lists the connection {'https://e2e-var.invalid/'}

    Scenario: the public half of a key of this computer is refused before anything is sent
        Given the test machine is being watched
        When I offer the public half of a key of this computer for {'ssh://e2e-pub.invalid/'} in the wizard
        Then it is refused before anything is sent
        When I leave the wizard
        Then the machine no longer lists the connection {'ssh://e2e-pub.invalid/'}

    # A private key of this computer goes into the vault on the machine, sent on standard input to the
    # command the machine names, and never into a file there.
    Scenario: a key of this computer is sent into the vault on the machine
        Given the test machine is being watched
        And the test machine has an open vault
        When I send a key of this computer into the vault for {'ssh://e2e-sent.invalid/'} from the interface
        Then the machine lists the connection {'ssh://e2e-sent.invalid/'} as a key in its vault
        When I forget the connection {'ssh://e2e-sent.invalid/'} from the interface
        Then the machine no longer lists the connection {'ssh://e2e-sent.invalid/'}
        And the vault entry of that key is removed again

    # A token is typed into a terminal on the machine, where it goes straight to vault put.
    Scenario: a token typed into a terminal on the machine lands in its vault
        Given the test machine is being watched
        And the test machine has an open vault
        When I store a token for {'https://e2e-typed.invalid/'} by typing it into a terminal on the machine
        Then the machine lists the connection {'https://e2e-typed.invalid/'} as a token in its vault
        When I forget the connection {'https://e2e-typed.invalid/'} from the interface
        Then the machine no longer lists the connection {'https://e2e-typed.invalid/'}
        And the vault entry of that key is removed again

    # A message a person wrote to a peer that is held waits for somebody: listed by the real machine,
    # read in full as written, and refused for good from the interface, which the machine confirms. The
    # refusal's words reach the task's inbox, and so do words a person writes to its agent.
    Scenario: a message held for a person is in what needs a person, read as written, and refused for good
        Given the test machine is being watched
        And the test machine has an open vault
        And the test machine has a task {'e2e-talk'} with a message held for {'reviewer'} saying {'look at **this** https://evil.example/x'}
        Then the interface shows a message held in {'porelo-e2e-talk-e2e-talk'}
        And the interface says {'you wrote, going out through'}
        When I read it and refuse it from the interface, saying {'not before the tests pass'}
        Then the message read as {'look at **this** https://evil.example/x'}
        And the interface says {'Refused for good. The task that wrote it is told, with your words.'}
        And the machine lists that message as refused by a person
        And the inbox of {'porelo-e2e-talk-e2e-talk'} holds {'not before the tests pass'}
        When I write {'stop, the schema changed'} to the agent of {'porelo-e2e-talk-e2e-talk'} from the interface
        Then the inbox of {'porelo-e2e-talk-e2e-talk'} holds {'stop, the schema changed'} from a person
        And the task {'porelo-e2e-talk-e2e-talk'} and the project {'e2e-talk'} are removed again

    # What a console can do with a destination, the interface can - checked by the machine first.
    Scenario: a destination is checked by the machine, written from the interface, and removed again
        Given the test machine is being watched
        When I add the destination {'e2e-weather'} at {'http://api.weather.invalid'} from the interface
        Then the interface says {'must be reached over https'}
        And the machine no longer lists the destination {'e2e-weather'}
        When I add the destination {'e2e-weather'} at {'https://api.weather.invalid/v1'} from the interface
        Then the machine lists the destination {'e2e-weather'} at {'https://api.weather.invalid/v1'}
        When I remove the destination {'e2e-weather'} from the interface
        Then the interface says {'Removed e2e-weather'}
        And the machine no longer lists the destination {'e2e-weather'}

    # A grant runs end to end: the machine asks a service, the page is shown, a person decides in a
    # browser (a stand-in's approval here), and the vault keeps who granted it.
    Scenario: an authorization is granted from the interface, and the machine records who granted it
        Given the test machine is being watched
        And the test machine has an open vault
        And the test machine has an entry {'e2e-grant'} a stand-in service grants
        When I grant {'e2e-grant'} from the interface
        Then the interface shows the page to decide on, whole
        When the stand-in service is told yes
        Then the interface says {'Granted. It is kept in the vault'}
        And the machine records {'e2e-grant'} as granted by the account the machine is reached as
        And the entry {'e2e-grant'} and its stand-in are removed again

    # A grant as GitHub's OAuth apps give it: no refresh token, no expiry. The token itself is
    # kept, granted from the interface as any other; only the person can end it at the service.
    Scenario: an authorization that never expires is granted from the interface, as GitHub grants one
        Given the test machine is being watched
        And the test machine has an open vault
        And the test machine has an entry {'e2e-lasting'} a stand-in service grants for good, as GitHub does
        When I grant {'e2e-lasting'} from the interface
        Then the interface shows the page to decide on, whole
        When the stand-in service is told yes
        Then the interface says {'Granted. It is kept in the vault'}
        And the interface says {'a token that does not expire, which removing it here cannot revoke'}
        And the machine records {'e2e-lasting'} as granted by the account the machine is reached as
        And the machine keeps the token of {'e2e-lasting'} itself, and removing it names where it is ended

    # A person's way into a project's conversation, end to end: the account made, the login shown once,
    # and the account's own homeserver reached from here through the forward the interface holds.
    Scenario: a person joins a project's conversation from the interface, and logs in through the forward
        Given the test machine is being watched
        And the test machine has an open vault
        And the test machine has a project {'e2e-mx'} with a conversation
        When I let a person join the conversation of {'e2e-mx'} from the interface
        Then the interface says this machine can carry the messages of the project
        And the login shown logs in to the homeserver through the forward
        And the project {'e2e-mx'} and its task are removed again

    # The question comes to whoever looks at what needs a person, not only to whoever started the work.
    Scenario: work started without a grant it needs is in what needs a person, and granted from there
        Given the test machine is being watched
        And the test machine has an open vault
        And the test machine has an entry {'e2e-needed'} a stand-in service grants
        And work on the test machine was started without a grant of {'e2e-needed'}
        When I grant {'e2e-needed'} from what needs a person in the interface
        And the stand-in service is told yes
        Then what needs a person no longer asks for {'e2e-needed'}
        And the work started without {'e2e-needed'} is removed again
        And the entry {'e2e-needed'} and its stand-in are removed again

    # An agent that ended is said where a person looks, in its provider's words, and what it wrote is on
    # its tile, read from the end of its log as the agent formats it.
    Scenario: work whose provider refused its key needs a person, and its tile shows what its agent wrote
        Given the test machine is being watched
        And the test machine has an open vault
        And the test machine has Porelo's stub agent
        And work on the test machine was started with a key {'anthropic'} its provider refuses
        Then what needs a person says its provider refused it
        And its tile shows what its agent wrote
        And the work its provider refused is removed again, with the key {'anthropic'}

    # Work without writing a project: default is every machine's, listed first, and a
    # repository is added to it by its address from the interface and taken out again.
    Scenario: a repository goes into default as work starts on it from the interface, and is taken out again
        Given the test machine is being watched
        And the test machine has a repository {'e2e-default'} to work on
        When I start work on the repository {'e2e-default'} in default from the interface, and put the start away
        Then the machine lists {'e2e-default'} in default
        When I take {'e2e-default'} out of default from the interface
        Then the machine lists nothing called {'e2e-default'} in default
        And the repository {'e2e-default'} is removed again from the test machine
