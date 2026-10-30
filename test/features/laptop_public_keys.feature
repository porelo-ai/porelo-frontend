Feature: Sharing this laptop's public host keys

    # Harm: a private half on the clipboard exposes this laptop's identity; replacing a copied key breaks admission.
    Scenario: copying again keeps the same host identity and exports no private half
        Given a laptop key copy dialog
        When I copy my public keys twice for {'orchard'}
        Then only the public halves reach the clipboard
