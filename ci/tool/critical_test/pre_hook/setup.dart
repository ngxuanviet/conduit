#! /usr/bin/env dcli

import 'dart:async';
import 'dart:io';

import 'package:conduit_common/conduit_common.dart';
import 'package:dcli/dcli.dart';
import 'package:conduit_dev_tools/conduit_dev_tools.dart';

/// This script will run the conduit unit tests
///
/// To run this script install dcli:
///
/// ```pub global activate dcli
/// ```
///
/// Then you can run:
///
/// ```
/// ./run_unit_tests.dart
/// ```
///
void main() {
  if (!whichEx('psql')) {
    printerr(red(
        'Postgres not found. Have you run "install_unit_test_dependencies.dart".'));
    exit(1);
  }

  final StreamSubscription<ProcessSignal> signalStream;

  signalStream = ProcessSignal.sigint.watch().listen((signal) {
    print('ctrl-caught');
    'docker-compose down'.run;
  });

  final projectRoot = DartProject.fromPath('.').pathToProjectRoot;
  DartSdk().runPubGet(projectRoot);

  var dbSettings = DbSettings.load(pathToSettings: projectRoot);
  var postgresManager = PostgresManager(dbSettings);

  if (dbSettings.useContainer) {
    print('Starting postgres docker image');
    postgresManager.startPostgresDaemon(projectRoot, dbSettings);
  }

  postgresManager.waitForPostgresToStart();

  print('recreating database');
  postgresManager.dropPostgresDb();

  /// we don't drop the user if we are using a container as
  /// we only have the one user.
  if (!dbSettings.useContainer) {
    postgresManager.dropUser();
  }

  postgresManager.createPostgresDb();

  print(blue('Running pub get on all projects'));
  DartScript.fromFile(join(projectRoot, 'bin', 'warmup.dart')).run([]);

  print(red('Activating local copy of conduit.'));
  // print(orange('You may want to revert this after the unit tests finish!'));

  // activate conduit from local sources
  DartSdk().globalActivateFromPath(projectRoot);
  signalStream.cancel();

  print('Activate finished');

  // print('Stopping posgress docker image');
  // postgresManager.stopPostgresDaemon(projectRoot);
}

// void activate(String projectRoot,  package) {
//   'pub global activate $package --source=path'.start(
//       workingDirectory: truepath(projectRoot, '..'));
// }
