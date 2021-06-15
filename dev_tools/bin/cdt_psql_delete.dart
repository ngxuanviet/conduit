#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';
import 'package:conduit_dev_tools/conduit_dev_tools.dart';

/// Used to reset the test database.
///
/// You shouldn't normally need to run this script as when a test run completes
/// normally, the database is droped when the docker container is shutdown.
///
/// If the tests aborted and left the container running this script will
/// shutdown the container and re-run the setup_unit_test script.
///

void main(List<String> args) {
  var dbSettings = DbSettings.load();

  final postgresManager = PostgresManager(dbSettings);

  final pathToCiProject =
      join(DartProject.fromPath('.').pathToProjectRoot, '..', 'ci');
  if (dbSettings.useContainer) {
    postgresManager.startPostgresDaemon(pathToCiProject, dbSettings);
  } else {
    postgresManager.waitForPostgresToStart();
  }

  postgresManager.dropPostgresDb();

  /// we don't drop the user if we are using a container as
  /// we only have the one user.
  if (!dbSettings.useContainer) {
    postgresManager.dropUser();
  }

  print(orange('Done.'));
}
