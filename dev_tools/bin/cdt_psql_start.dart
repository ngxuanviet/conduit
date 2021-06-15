#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';
import 'package:conduit_dev_tools/conduit_dev_tools.dart';

/// Starts the postgres daemon (assuming it is configured to work with a container)
/// Waits for it to be fully started
/// and then creates the test db.
///
/// Use this script if you need to run individual unit tests which require postgres to
/// be running.
///
/// run this script:
///
/// install dcli via:
///
/// ```
/// pub global activate dcli
/// ```
///
/// Then run script:
/// ./start_db.dart
///

void main(List<String> args) {
  var dbSettings = DbSettings.load();

  final postgresManager = PostgresManager(dbSettings);

  if (postgresManager.isPostgresRunning()) {
    print('Postgres is already running');
  }

  if (dbSettings.useContainer) {
    postgresManager.startPostgresDaemon('.', dbSettings);
  } else {
    postgresManager.waitForPostgresToStart();
  }

  postgresManager.dropPostgresDb();

  /// we don't drop the user if we are using a container as
  /// we only have the one user.
  if (!dbSettings.useContainer) {
    postgresManager.dropUser();
  }

  postgresManager.createPostgresDb();

  print(orange('Postgres is ready.'));
}
