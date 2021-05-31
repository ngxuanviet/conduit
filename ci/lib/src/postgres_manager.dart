import 'dart:io';

import 'package:dcli/dcli.dart';

import 'db_settings.dart';

/// We have our own copy of the PostgresManager as during testing
/// we have to switch to a local copy of conduit which means
/// the package paths get screwed up.
class PostgresManager {
  PostgresManager(this._dbSettings);

  final DbSettings _dbSettings;

  bool isPostgresClientInstalled() => which('psql').found;

  /// Checks if the posgres service is running and excepting commands
  bool isPostgresRunning() {
    _setPassword();

    /// create user
    final results =
        "psql --host=${_dbSettings.host} --port=${_dbSettings.port} -c 'select 42424242;' -q -t -U ${_dbSettings.username} postgres "
            .toList(nothrow: true);

    if (results.first.contains('password authentication failed')) {
      throw Exception('Invalid password. Check your .settings.yaml');
    }

    return results.first.contains('42424242');
  }

  bool doesDbExist() {
    _setPassword();

    /// lists the database.
    final sql =
        "psql --host=${_dbSettings.host} --port=${_dbSettings.port} -t -q -c '\\l ${_dbSettings.dbName};' -U ${_dbSettings.username}";

    final results = sql.toList(skipLines: 1);

    return results.isNotEmpty &&
        results.first.contains('${_dbSettings.dbName}');
  }

  void createPostgresDb() {
    print('Creating database');

    final save = _setPassword();

    /// create user
    "psql --host=${_dbSettings.host} --port=${_dbSettings.port} -c 'create user ${_dbSettings.username} with createdb;' -U ${_dbSettings.username}"
        .run;

    /// set password
    Settings().setVerbose(enabled: false);
    '''psql --host=${_dbSettings.host} --port=${_dbSettings.port} -c "alter user ${_dbSettings.username} with password '${_dbSettings.password}';" -U ${_dbSettings.username}'''
        .run;
    Settings().setVerbose(enabled: save);

    /// create db
    "psql --host=${_dbSettings.host} --port=${_dbSettings.port} -c 'create database ${_dbSettings.dbName};' -U ${_dbSettings.username}"
        .run;

    /// grant permissions
    "psql --host=${_dbSettings.host} --port=${_dbSettings.port} -c 'grant all on database ${_dbSettings.dbName} to ${_dbSettings.username};' -U ${_dbSettings.username} "
        .run;
  }

  /// Creates the enviornment variable that postgres requires to obtain the users's password.
  bool _setPassword() {
    final save = Settings().isVerbose;
    Settings().setVerbose(enabled: false);
    env['PGPASSWORD'] = _dbSettings.password;
    Settings().setVerbose(enabled: save);
    return save;
  }

  void dropPostgresDb() {
    _setPassword();

    "psql --host=${_dbSettings.host} --port=${_dbSettings.port} -c 'drop database if exists  ${_dbSettings.dbName};' -U ${_dbSettings.username}"
        .run;
  }

  void dropUser() {
    _setPassword();

    "psql --host=${_dbSettings.host} --port=${_dbSettings.port} -c 'drop user if exists  ${_dbSettings.username};' -U ${_dbSettings.username}"
        .run;
  }

  void waitForPostgresToStart() {
    print('Waiting for postgres to start.');
    while (!isPostgresRunning()) {
      stdout.write('.');
      waitForEx(stdout.flush());
      sleep(1);
    }
    print('');
  }

  void configurePostgress() {
    if (!_dbSettings.useContainer) {
      print(
          'As you have selected to use your own postgres server, we can automatically create the unit test db.');
      if (confirm(
          'Do you want the conduit test database ${_dbSettings.dbName}  created?')) {
        createPostgresDb();
      }
    } else {
      createPostgresDb();
    }
  }

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

  void startPostgresDaemon(String pathToTool) {
    print('Starting docker postgres image');
    'docker-compose up -d'.start(workingDirectory: pathToTool);

    waitForPostgresToStart();
  }

  void stopPostgresDaemon(String pathToTool) {
    print('Stoping docker postgres image');
    'docker-compose down'.start(workingDirectory: pathToTool);
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

  void installPostgresClient() {
    if (isPostgresClientInstalled()) {
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
}

bool isAptInstalled() => which('apt').found;
