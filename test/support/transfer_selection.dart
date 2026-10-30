import 'package:porelo_frontend/src/app/machines.dart';
import 'package:porelo_frontend/src/app/project_transfers.dart';
import 'package:porelo_host/porelo_host.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

TransferSelection selection({
  bool allowed = true,
  List<String> repositories = const ['api'],
  String person = 'alice',
  String forge = 'example.org',
  String project = 'example',
}) => TransferSelection(
  machine: Machine.fromHostCard(
    HostCardSsh(
      name: 'alpha',
      address: 'alpha.example.org',
      sshPort: 22,
      hostKey: _key,
      login: 'alice',
      publicKey: _key,
      uid: 1001,
      returnSocket: '/run/porelo-host/people/alice/messenger.sock',
      webPort: 18080,
      gitPort: 18081,
      matrixPort: 18082,
    ),
    socketPath: '/run/person/daemon.sock',
  ),
  person: person,
  forge: forge,
  project: project,
  canPush: allowed,
  repositories: repositories,
);
