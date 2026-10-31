import 'package:flutter/material.dart';

import '../app/run_here.dart' show WorkspaceRefused;

import '../app/registry_checkout.dart';
import 'tokens.dart';

/// Asks for the organisation's registry repository and answers the checked address, or null when cancelled.
///
/// Only an address is taken: Git reaches it with the person's own SSH key or credential helper, so an
/// address with a user name, password or token is refused without being repeated.
Future<String?> chooseRegistryAddress(BuildContext context, {String? current}) => showDialog<String>(
  context: context,
  builder: (context) => _RegistryAddressDialog(current: current),
);

class _RegistryAddressDialog extends StatefulWidget {
  const _RegistryAddressDialog({this.current});

  final String? current;

  @override
  State<_RegistryAddressDialog> createState() => _RegistryAddressDialogState();
}

class _RegistryAddressDialogState extends State<_RegistryAddressDialog> {
  late final _address = TextEditingController(text: widget.current);
  String? _refused;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _take() {
    final address = _address.text.trim();
    try {
      RegistryCheckout.checkRepository(address);
    } on WorkspaceRefused catch (refused) {
      setState(() => _refused = refused.words);
      return;
    }
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('The registry repository'),
    content: SizedBox(
      width: Sizes.dialogSmall,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "The repository on the central forge that holds your organisation's person cards, hosts and "
            'projects. Its address is on the forge, under Code: the SSH one (git@…) or the HTTPS one. '
            'Porelo reads it with your own SSH key or your Git sign-in; give the address only, no token.',
          ),
          const SizedBox(height: Space.normal),
          TextField(
            key: const Key('registry-address'),
            controller: _address,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Repository address',
              hintText: 'git@github.com:your-organisation/registry.git',
              errorText: _refused,
            ),
            onSubmitted: (_) => _take(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(key: const Key('registry-address-take'), onPressed: _take, child: const Text('Read it')),
    ],
  );
}
