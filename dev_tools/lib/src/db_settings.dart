import 'package:dcli/dcli.dart';
import 'package:settings_yaml/settings_yaml.dart';

/// We have our own copy of the DbSettings as during testing
/// we have to switch to a local copy of conduit which means
/// the package paths get screwed up.

class DbSettings {
  DbSettings(
      {required this.adminUsername,
      required this.adminPassword,
      required this.username,
      required this.password,
      required this.dbName,
      required this.host,
      required this.port});

  DbSettings.load({String pathToSettings = '.'}) {
    _load(pathToSettings);
  }

  static const filePath = '.settings.yaml';

  static const defaultAdminUsername = 'postgres';
  static const defaultAdminPassword = 'postgres!';
  static const defaultUsername = 'conduit_test_user';
  static const defaultPassword = 'conduit!';
  static const defaultDbName = 'conduit_test_db';
  static const defaultHost = 'localhost';
  static const defaultPort = 15432;
  static const defaultUseContainer = true;

  static const keyPostgresAdminUsername = 'POSTGRES_ADMIN_USER';
  static const keyPostgresAdminPassword = 'POSTGRES_ADMIN_PASSWORD';
  static const keyPostgresUsername = 'POSTGRES_USER';
  static const keyPostgresPassword = 'POSTGRES_PASSWORD';
  static const keyPSQLDbName = 'POSTGRES_DB';
  static const keyPostgresPort = 'POSTGRES_PORT';
  static const keyPostgresHost = 'POSTGRES_HOST';
  static const keyUseContainer = 'useContainer';

  late String adminUsername;
  late String adminPassword;
  late String username;
  late String password;
  late String dbName;
  late String host;
  late int port;

  /// If true then we are using a docker postgres container
  /// If false we are using a user supplied postgres daemon.
  late bool useContainer;

  /// create the necessary environment variables for the
  /// postgres docker image to start using the non-admin u/p
  void createEnvironmentVariables() {
    env[keyPostgresHost] = host;
    env[keyPostgresPort] = '$port';
    env[keyPostgresUsername] = username;
    env[keyPostgresPassword] = password;
    env[keyPSQLDbName] = dbName;

    print('Creating environment variables for db settings.');

    print('$keyPostgresHost ${env[keyPostgresHost]}');
    print('$keyPostgresPort = ${env[keyPostgresPort]}');
    print('$keyPostgresUsername = ${env[keyPostgresUsername]}');
    print('$keyPostgresPassword = ${env[keyPostgresPassword]}');
    print('$keyPSQLDbName = ${env[keyPSQLDbName]}');
    print('$keyUseContainer = $useContainer');

    print('');
  }

  void _load(String pathToSettings) {
    final settings =
        SettingsYaml.load(pathToSettings: join(pathToSettings, filePath));

    adminUsername =
        settings[keyPostgresAdminUsername] as String? ?? defaultAdminUsername;
    adminPassword =
        settings[keyPostgresAdminPassword] as String? ?? defaultAdminPassword;
    username = settings[keyPostgresUsername] as String? ?? defaultUsername;
    password = settings[keyPostgresPassword] as String? ?? defaultPassword;
    dbName = settings[keyPSQLDbName] as String? ?? defaultDbName;
    host = settings[keyPostgresHost] as String? ?? defaultHost;
    port =
        int.tryParse(settings[keyPostgresPort] as String? ?? '$defaultPort') ??
            defaultPort;
    useContainer = settings[keyUseContainer] as bool? ?? defaultUseContainer;
  }

  void save() {
    final settings = SettingsYaml.load(pathToSettings: filePath);

    settings[keyPostgresHost] = host;
    settings[keyPostgresPort] = '$port';
    settings[keyPostgresAdminUsername] = adminUsername;
    settings[keyPostgresAdminPassword] = adminPassword;
    settings[keyPostgresUsername] = username;
    settings[keyPostgresPassword] = password;
    settings[keyPSQLDbName] = dbName;
    settings[keyUseContainer] = useContainer;

    settings.save();
  }
}
