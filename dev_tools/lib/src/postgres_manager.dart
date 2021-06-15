import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:conduit_common/conduit_common.dart';

import 'db_settings.dart';
import 'install/test_dependencies.dart';

/// We have our own copy of the PostgresManager as during testing
/// we have to switch to a local copy of conduit which means
/// the package paths get screwed up.
class PostgresManager {
  PostgresManager(this._dbSettings);

  final DbSettings _dbSettings;

  bool isPostgresClientInstalled() => whichEx('psql');

  /// Checks if the posgres service is running and excepting commands
  bool isPostgresRunning() {
    _setPassword();

    /// run a simple select to see that we get a result and therefor the postgres server must be up.
    final results =
        "psql $connectionStringAdminPostgres -q -t  -c 'select 42424242;'"
            .toList(nothrow: true);

    if (results.first.contains('password authentication failed')) {
      throw Exception('Invalid password. Check your .settings.yaml');
    }

    return results.first.contains('42424242');
  }

  String get connectionString =>
      '$connectionStringHostPort --username=${_dbSettings.username} --dbname=${_dbSettings.dbName}';

  String get connectionStringSansDbName =>
      '$connectionStringHostPort --username=${_dbSettings.username}';

  String get connectionStringAdmin =>
      '$connectionStringHostPort --username=${_dbSettings.adminUsername} --dbname=${_dbSettings.adminUsername}';

  String get connectionStringAdminSansDbName =>
      '$connectionStringHostPort --username=${_dbSettings.adminUsername}';

  /// the postgres db always exists and we need to use this connection if our test db
  /// doesn't exist.
  String get connectionStringAdminPostgres =>
      '$connectionStringHostPort --username=${_dbSettings.adminUsername} --dbname=postgres';

  String get connectionStringHostPort =>
      '--host=${_dbSettings.host} --port=${_dbSettings.port}';

  bool doesDbExist() {
    _setPassword(admin: true);

    /// lists the database.
    final sql =
        "psql $connectionStringAdminSansDbName -t -q -c '\\l ${_dbSettings.dbName};' ";

    final results = sql.toList(skipLines: 1);

    return results.isNotEmpty &&
        results.first.contains('${_dbSettings.dbName}');
  }

  void createPostgresDb() {
    print('Creating database');

    final save = _setPassword(admin: true);

    if (!usersExists(_dbSettings.username)) {
      /// create user
      "psql $connectionStringAdminSansDbName --dbname=postgres -c 'create user ${_dbSettings.username} with createdb;'"
          .run;

      /// set password
      Settings().setVerbose(enabled: false);
      '''psql $connectionStringAdminSansDbName --dbname=postgres -c "alter user ${_dbSettings.username} with password '${_dbSettings.password}';"'''
          .run;
      Settings().setVerbose(enabled: save);
    }

    /// create db
    "psql $connectionStringAdminSansDbName --dbname=postgres  -c 'create database ${_dbSettings.dbName};'"
        .run;

    /// grant permissions
    "psql $connectionStringAdminSansDbName --dbname=postgres -c 'grant all on database ${_dbSettings.dbName} to ${_dbSettings.username};'"
        .run;
  }

  /// Creates the enviornment variable that psql requires to obtain the users's password.
  bool _setPassword({bool admin = false}) {
    final save = Settings().isVerbose;
    Settings().setVerbose(enabled: false);
    env['PGPASSWORD'] =
        admin ? _dbSettings.adminPassword : _dbSettings.password;
    Settings().setVerbose(enabled: save);
    return save;
  }

  void dropPostgresDb() {
    _setPassword(admin: true);

    "psql $connectionStringAdminSansDbName --dbname=postgres -c 'drop database if exists  ${_dbSettings.dbName};'"
        .run;
  }

  void dropUser() {
    print(red('An attempt was made to drop the user'));
    _setPassword(admin: true);

    "psql $connectionStringAdminSansDbName -c 'drop user if exists  ${_dbSettings.username};'"
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

  void createTestDatabase() {
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

  void startPostgresDaemon(String pathToCIProjectRoot, DbSettings dbSettings) {
    dbSettings.createEnvironmentVariables();
    print('Starting docker postgres image');
    'docker-compose up -d'.start(workingDirectory: pathToCIProjectRoot);

    waitForPostgresToStart();
  }

  void stopPostgresDaemon(String pathToCIProjectRoot) {
    print('Stoping docker postgres image');
    'docker-compose down'.start(workingDirectory: pathToCIProjectRoot);
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
      if (Platform.isWindows) {
        print(
            'Find download instructions at: https://www.postgresql.org/download/windows/');
      }
      exit(1);
    }
  }

  bool usersExists(String username) {
    final sql =
        '''psql $connectionStringAdminPostgres -t -q -c "SELECT 'userfound' FROM pg_roles WHERE rolname='$username';" ''';

    final results = sql.toList();

    return results.isNotEmpty && results.first.contains('userfound');
  }
}
