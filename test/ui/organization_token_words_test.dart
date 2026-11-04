import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/app/organization_source.dart';
import 'package:porelo_frontend/src/ui/organization_token_words.dart';

void main() {
  OrganizationView at(String address) =>
      OrganizationView(name: 'acme', keptIn: '', address: address, vouchedBy: '', revision: 'r', me: 'hana');

  // Harm: a token kept for a host's usual forge is sent for another forge on another port of that host.
  test('a token is used only for the forge it is kept for', () {
    expect(organizationKeptTokenAddress(at('git@github.com:acme/org.git')), 'github.com');
    expect(organizationKeptTokenAddress(at('https://github.com/acme/org.git')), 'github.com');
    expect(organizationKeptTokenAddress(at('org@forge.example.org:acme/org.git')), 'forge.example.org');
    expect(organizationKeptTokenAddress(at('https://forge.example.org:8443/acme/org.git')), isNull);
  });
}
