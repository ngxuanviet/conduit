import 'dart:io';

import 'package:conduit_dev_tools/src/postgres_manager.dart';
import 'package:dcli/dcli.dart';

import 'test_dependencies.dart';

bool isPostgresDaemonInstalled() {
  var found = false;
  final images = 'docker images'.toList(skipLines: 1);

  for (var image in images) {
    image = image.replaceAll('  ', ' ');
    final parts = image.split(' ');
    if (parts.isNotEmpty && parts[0] == 'postgres') {
      found = true;
      break;
    }
  }
  return found;
}

void startPostgresDaemon(PostgresManager pmgr) {
  print('Starting docker postgres image');
  'docker-compose up -d'.run;

  pmgr.waitForPostgresToStart();
}

void stopPostgresDaemon() {
  print('Stoping docker postgres image');
  'docker-compose down'.run;
}

/// Postgres functions
void installPostgressDaemon() {
  if (isPostgresDaemonInstalled()) {
    print('Using existing postgress daemon.');
    return;
  }

  print('Installing postgres docker image');
  'docker pull postgres'.run;
}

void installPostgresClient(PostgresManager pmgr) {
  if (pmgr.isPostgresClientInstalled()) {
    print('Using existing postgress client.');
    return;
  }

  if (isAptInstalled()) {
    print('Installing postgres client');
    'apt  --assume-yes install postgresql-client'.start(privileged: true);
  } else {
    printerr(
        red('psql is not installed. Please install psql and start again.'));
    exit(1);
  }
}
