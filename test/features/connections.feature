# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: How a machine connects out, and giving it a credential

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    # The list holds no secret, so it is read with the vault shut — which is what tells "configured,
    # open the vault" from "nothing here".
    Scenario: connections are listed with the vault shut, one outside it marked not protected
        Given the store is shut
        And the machine connects to {'ssh://github.com'} with a key in the vault
        And the machine connects to {'https://gitlab.example/acme/'} with a token in a file
        When I choose the command {'Connections — how this machine connects out'}
        Then it says {'ssh://github.com'}
        And it says {'the vault is shut, so nothing can say whether its value is there'}
        And the connection {'https://gitlab.example/acme/'} is marked not protected
        And the connection {'ssh://github.com'} is not marked not protected

    # Where somebody looks for them without the finder: the machine's own menu, under the word itself.
    Scenario: the machine's menu opens its connections
        When I open the menu {'What this machine can be told to do'}
        Then the menu offers {'Connections — how this machine connects out'}
        When I choose the menu entry {'Connections — how this machine connects out'}
        Then the connections of the machine are open

    # https may be a token or a user and password, so the address cannot decide it. Only the purposes
    # the machine reads are offered, and OAuth is not: nothing would ever renew its token.
    Scenario: what a connection is, is chosen and never read off its address
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://gitlab.example/acme/'}
        Then going on is not offered yet
        And the dialog offers {'any use'}
        And the dialog does not offer {'An OAuth token'}
        When I choose it to be {'TOKEN'}
        Then going on is offered
        And no two fields of the dialog overlap
        And the dialog shows its scrollbar and its first label whole

    Scenario: a token in the vault is typed into a terminal on the machine, after the check
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://gitlab.example/acme/'}
        And I choose it to be {'TOKEN'}
        And I go on
        And I choose {'In the vault, typed at the machine'}
        Then it says {'a terminal on the machine opens'}
        When I go on
        Then it says {'Nothing stands in the way'}
        And nothing was declared
        When I add it
        Then it was declared as {'TOKEN'} for {'https://gitlab.example/acme/'}, kept in {'VAULT'}
        And a terminal runs {'porelo vault put git.token.example --type token'} on the machine

    # The one secret this interface carries: a private key of this computer, sent once into the vault.
    Scenario: an ssh key of this computer is filled from its file and sent into the vault
        Given this computer has the key {'id_work'}
        And the file dialog will answer with the key {'id_work'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key of this computer, sent into the vault'}
        And I fill the key from a file
        And I go on
        And I add it
        Then the machine was given a key by {'porelo vault put git.ssh.example'}
        And the status line mentions {'is stored on'}

    # Only the private key is sent: the machine works out the public half, and a public one stored in
    # its place would be refused at the first fetch, far from where the wrong file was chosen.
    Scenario: the public half chosen from this computer is refused before anything is sent
        Given this computer has the key {'id_work'}
        And the file dialog will answer with the key {'id_work.pub'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key of this computer, sent into the vault'}
        And I fill the key from a file
        Then it says {'That is the public half of a key'}
        And the private key field is empty
        And going on is not offered yet
        And nothing was given to the machine

    Scenario: pasted text that is no key at all is refused, and leaves the field
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key of this computer, sent into the vault'}
        And I paste the private key {'hunter2'}
        Then what a walk writes down does not hold {'hunter2'}
        And the {'connection-private-key'} is blanked in a walk's picture
        When I go on
        Then it says {'That is not a private key'}
        And the wizard is at step {'2'}
        And the private key field is empty
        And nothing was declared

    # Going back keeps every description and never a secret.
    Scenario: going back from the check takes the pasted key out of its field
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key of this computer, sent into the vault'}
        And I paste a private key
        And I go on
        Then the wizard is at step {'3'}
        When I go back
        Then the wizard is at step {'2'}
        And the private key field is empty

    # The machine says which files are keys — that takes reading them, and they stay there. Only one
    # with its private half is offered: ssh signs with that file.
    Scenario: a key already on the machine is picked from its list and used where it lies
        Given the machine has the key {'/home/me/.ssh/id_ed25519'}
        And the machine has only the public half of {'/home/me/.ssh/company_key'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key already on the machine'}
        Then the dialog offers {'/home/me/.ssh/id_ed25519'}
        And the dialog does not offer {'/home/me/.ssh/company_key'}
        And going on is not offered yet
        When I choose {'/home/me/.ssh/id_ed25519'}
        Then it says {'me@laptop'}
        When I go on
        And I add it
        Then it was declared with the key {'/home/me/.ssh/id_ed25519'}
        And it says {'Its value is already where it says'}

    # The machine reads the file from its own disk: nothing of the key passes through here.
    Scenario: a key already on the machine is copied into the vault by the machine
        Given the machine has the key {'/home/me/.ssh/id_ed25519'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key already on the machine'}
        And I choose {'/home/me/.ssh/id_ed25519'}
        And I choose {'Copied into the vault by the machine'}
        And I go on
        And I add it
        Then it was declared into the vault from the file {'/home/me/.ssh/id_ed25519'}
        And the machine ran {'porelo vault put git.ssh.example --from-file /home/me/.ssh/id_ed25519'} with nothing on its standard input

    # A key for another account or another repository looks good until the first fetch; only the
    # machine can ask the forge, and what the forge says is put beside the key.
    Scenario: the check says who a key logs in as
        Given the machine has the key {'/home/me/.ssh/id_ed25519'}
        And the forge says {'/home/me/.ssh/id_ed25519'} logs in as {'Hi fuinorg/utils4j!'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://github.com/'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key already on the machine'}
        And I choose {'/home/me/.ssh/id_ed25519'}
        And I go on
        Then it says {'logs in as: Hi fuinorg/utils4j!'}

    # The machine refuses what could only fail, and the check shows that before anything is written.
    Scenario: an ssh key for an https address is refused by the check, and cannot be added
        Given the machine has the key {'/home/me/.ssh/id_ed25519'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://github.com/acme/'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key already on the machine'}
        And I choose {'/home/me/.ssh/id_ed25519'}
        And I go on
        Then it says {'This would not work as it is'}
        And it says {'never for an ssh key'}
        And adding it is not offered yet
        When I go back
        Then the wizard is at step {'2'}

    Scenario: a machine without a private key says so, rather than showing an empty list
        Given the machine has only the public half of {'/home/me/.ssh/company_key'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key already on the machine'}
        Then it says {'This machine has no private key'}
        And going on is not offered yet

    # A Porelo older than the listing is not a machine without keys: the path is typed, and why is said.
    Scenario: a machine that cannot list its keys takes a typed path, never its public half
        Given the machine cannot list its keys
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And it is kept in the file {'/home/me/.ssh/id_work.pub'} on the machine
        Then it says {'cannot list its keys yet, so its path is typed'}
        And it says {'That is the public half'}
        And going on is not offered yet

    # A space after the name is not a different file: the check and what is sent read the same path.
    Scenario: a public half typed with a space after it is still the public half
        Given the machine cannot list its keys
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And it is kept in the file {'/home/me/.ssh/id_work.pub '} on the machine
        Then it says {'That is the public half'}
        And going on is not offered yet

    Scenario: a variable the machine does not have is refused by the check
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://gitlab.example/acme/'}
        And I choose it to be {'TOKEN'}
        And I go on
        And I choose {'A variable on the machine'}
        And I name the variable {'GITLAB_TOKEN'}
        And I go on
        Then it says {'This would not work as it is'}
        And adding it is not offered yet

    # Typing moves faster than a machine answers: only the answer to what is on screen counts.
    Scenario: an answer to an earlier check never replaces the answer to the one on screen
        Given the machine has the variable {'GITLAB_PASSWORD'}
        And the machine answers each check only when told
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://gitlab.example/acme/'}
        And I choose it to be {'TOKEN'}
        And I go on
        And I choose {'A variable on the machine'}
        And I name the variable {'GITLAB_TOKEN'}
        And I go on
        And I go back
        And I name the variable {'GITLAB_PASSWORD'}
        And I go on
        And the machine answers the later check, then the earlier one
        And I add it
        Then it was declared as {'TOKEN'} for {'https://gitlab.example/acme/'}, kept in {'ENVIRONMENT'}

    Scenario: a user and password from two variables are declared by their names
        Given the machine has the variable {'GITLAB_PASSWORD'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://gitlab.example/acme/'}
        And I choose it to be {'BASIC'}
        And I go on
        And I choose {'Two variables on the machine'}
        And I name the variable of the user {'GITLAB_USER'}
        And I name the variable {'GITLAB_PASSWORD'}
        And I go on
        And I add it
        Then it was declared with the user taken from the variable {'GITLAB_USER'}
        And it was declared as {'BASIC'} for {'https://gitlab.example/acme/'}, kept in {'ENVIRONMENT'}

    Scenario: a user and password in the vault have the password typed at the machine
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://gitlab.example/acme/'}
        And I choose it to be {'BASIC'}
        And I go on
        And I choose {'In the vault, the password typed at the machine'}
        And I name the user {'me'}
        And I go on
        And I add it
        Then a terminal runs {'porelo vault put git.token.example'} on the machine

    # A vault that is not there is made at the machine, from the check, and then asked about again.
    Scenario: an account without a vault is sent to make one, and checked again
        Given the machine has no store yet
        And the machine is reached over ssh as {'alice@vm'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://gitlab.example/acme/'}
        And I choose it to be {'TOKEN'}
        And I go on
        And I choose {'In the vault, typed at the machine'}
        And I go on
        Then it says {'no vault yet'}
        And adding it is not offered yet
        When I make the vault from the check
        Then a terminal runs {'ssh -t alice@vm porelo vault init'} on the machine
        When the unlock terminal ends and is put away
        Then the machine was asked again whether it would work

    Scenario: a shut vault is opened from the check, and checked again
        Given the store is shut
        And the machine is reached over ssh as {'alice@vm'}
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://gitlab.example/acme/'}
        And I choose it to be {'TOKEN'}
        And I go on
        And I choose {'In the vault, typed at the machine'}
        And I go on
        Then it says {'the vault is shut'}
        When I open the vault from the check
        Then a terminal runs {'ssh -t alice@vm porelo vault unlock'} on the machine
        When the unlock terminal ends and is put away
        Then the machine was asked again whether it would work

    Scenario: leaving the wizard declares nothing
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'https://gitlab.example/acme/'}
        And I choose it to be {'TOKEN'}
        And I go on
        And I choose {'In the vault, typed at the machine'}
        And I go on
        And I choose {'Leave it'}
        Then nothing was declared


    Scenario: forgetting a connection says the value is still there
        Given the machine connects to {'ssh://github.com'} with a key in the vault
        When I choose the command {'Connections — how this machine connects out'}
        And I forget the connection {'ssh://github.com'}
        Then it says {'Its value is still there'}
        And it says {'Remove that at the machine'}


    # What was sent leaves this interface whether or not storing worked, and the way to try again
    # stays on screen.
    Scenario: a key that could not be stored leaves the way to try again
        Given storing on the machine will fail
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key of this computer, sent into the vault'}
        And I paste a private key
        And I go on
        And I add it
        Then the status line mentions {'Storing the key did not work'}
        And the way to store it is still offered
        And nothing pasted is left on screen

    # Trying again from what stays on screen refuses a public half the same way the wizard does.
    Scenario: trying again with a public half is refused beside the way to try again
        Given storing on the machine will fail
        When I choose the command {'Connections — how this machine connects out'}
        And I add a connection to {'ssh://gitlab.example'}
        And I choose it to be {'SSH_KEY'}
        And I go on
        And I choose {'A key of this computer, sent into the vault'}
        And I paste a private key
        And I go on
        And I add it
        And I paste {'ssh-ed25519 AAAAC3Nza me@work'} and send it
        Then the way to store it says {'That is the public half of a key'}
        And nothing pasted is left on screen
        And the {'store-paste'} is blanked in a walk's picture
