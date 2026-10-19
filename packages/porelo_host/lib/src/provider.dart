/// What a provider is asked for, to rent one host.
class HostRequest {
  /// Constructor taking everything a rented host is made from.
  const HostRequest({required this.name, required this.tags, required this.sshPublicKey, this.userData});

  /// The host's name at the provider, which is also its hostname.
  final String name;

  /// The tags it carries. **A host is found again by its tags alone**, so a second `up` rents
  /// nothing and a `down` gives back only what this package rented.
  final List<String> tags;

  /// The public key that logs in first.
  final String sshPublicKey;

  /// What cloud-init runs at the first boot, where the provider takes it.
  final String? userData;
}

/// One rented host, as its provider reports it.
class RentedHost {
  /// Constructor taking what the provider said.
  const RentedHost({required this.id, required this.address, required this.hostKey, required this.ready});

  /// The provider's own id for it.
  final String id;

  /// Where ssh reaches it, or null while it has none yet.
  final String? address;

  /// Its ssh host key as `<type> <base64>`, or null while the provider has not reported it.
  ///
  /// **Taken from the provider, never from the host itself.** A key fetched over the network the
  /// first time is the one step a man in the middle needs; the provider is the party that made
  /// the machine.
  final String? hostKey;

  /// Whether it is installed and booted, so ssh may be tried.
  final bool ready;
}

/// A provider that rents hosts and gives them back. One adapter per provider.
abstract interface class HostProvider {
  /// The host tagged [tag], or null when none is.
  Future<RentedHost?> find(String tag);

  /// Rents one host as [request] says.
  Future<RentedHost> create(HostRequest request);

  /// What the provider says now about the host [id].
  Future<RentedHost> state(String id);

  /// Gives the host [id] back.
  Future<void> release(String id);
}

/// A host somebody has already: rents nothing and gives nothing back.
///
/// For the tests, and for a person whose machine exists. Its address and host key are given, as a
/// provider would report them.
class GivenMachine implements HostProvider {
  /// Constructor taking where the machine is and its host key.
  GivenMachine({required this.address, required this.hostKey});

  /// Where ssh reaches it.
  final String address;

  /// Its host key, as `<type> <base64>`.
  final String hostKey;

  RentedHost get _it => RentedHost(id: address, address: address, hostKey: hostKey, ready: true);

  @override
  Future<RentedHost?> find(String tag) async => _it;

  @override
  Future<RentedHost> create(HostRequest request) async => _it;

  @override
  Future<RentedHost> state(String id) async => _it;

  @override
  Future<void> release(String id) async {}
}

/// What the provider refused, in its own words.
class ProviderFailed implements Exception {
  /// Constructor taking what happened.
  const ProviderFailed(this.message);

  /// What happened, in words; never the key.
  final String message;

  @override
  String toString() => message;
}
