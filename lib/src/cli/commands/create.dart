import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conduit/src/cli/command.dart';
import 'package:conduit/src/cli/metadata.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path/path.dart';
import 'package:pub_cache/pub_cache.dart';
import 'package:yaml/yaml.dart';

/// Used internally.
class CLITemplateCreator extends CLICommand with CLIConduitGlobal {
  CLITemplateCreator() {
    registerCommand(CLITemplateList());
  }

  @Option("template",
      abbr: "t", help: "Name of the template to use", defaultsTo: "default")
  String get templateName => decode("template");

  @Flag("offline",
      negatable: false,
      help: "Will fetch dependencies from a local cache if they exist.",
      defaultsTo: false)
  bool get offline => decode("offline");

  String? get projectName =>
      remainingArguments.isNotEmpty ? remainingArguments.first : null;

  @override
  Future<int> handle() async {
    if (projectName == null) {
      printHelp(parentCommandName: "conduit");
      return 1;
    }

    if (!isSnakeCase(projectName!)) {
      displayError("Invalid project name ($projectName is not snake_case).");
      return 1;
    }

    var destDirectory = destinationDirectoryFromPath(projectName!);
    if (destDirectory.existsSync()) {
      displayError("${destDirectory.path} already exists, stopping.");
      return 1;
    }

    destDirectory.createSync();

    final templateSourceDirectory =
        Directory.fromUri(getTemplateLocation(templateName) ?? Uri());
    if (!templateSourceDirectory.existsSync()) {
      displayError("No template at ${templateSourceDirectory.path}.");
      return 1;
    }

    displayProgress("Template source is: ${templateSourceDirectory.path}");
    displayProgress("See more templates with 'conduit create list-templates'");
    copyProjectFiles(destDirectory, templateSourceDirectory, projectName!);

    createProjectSpecificFiles(destDirectory.path);
    try {
      final conduitLocation = conduitPackageRef!.resolve()!.location;
      if (conduitPackageRef?.sourceType == "path") {
        if (!addDependencyOverridesToPackage(destDirectory.path, {
          "conduit": conduitLocation.uri,
          "conduit_test": _packageUri(conduitLocation, 'test_harness'),
          "conduit_codable": _packageUri(conduitLocation, 'codable'),
          "conduit_common": _packageUri(conduitLocation, 'common'),
          "conduit_common_test": _packageUri(conduitLocation, 'common_test'),
          "conduit_config": _packageUri(conduitLocation, 'config'),
          "conduit_isolate_exec": _packageUri(conduitLocation, 'isolate_exec'),
          "conduit_open_api": _packageUri(conduitLocation, 'open_api'),
          "conduit_password_hash":
              _packageUri(conduitLocation, 'password_hash'),
          "conduit_runtime": _packageUri(conduitLocation, 'runtime'),
        })) {
          displayError(
              'You are running from a local source (pub global activate --source=path) version of conduit and are missing the source for some dependencies.');
          throw StateError;
        }
      }
    } catch (e) {
      displayError(e.toString());
      return 1;
    }

    displayInfo(
        "Fetching project dependencies (pub get ${offline ? "--offline" : ""})...");
    displayInfo("Please wait...");
    try {
      await fetchProjectDependencies(destDirectory, offline: offline);
    } on TimeoutException {
      displayInfo(
          "Fetching dependencies timed out. Run 'pub get' in your project directory.");
    }

    displayProgress("Success.");
    displayInfo("project '$projectName' successfully created.");
    displayProgress("Project is located at ${destDirectory.path}");
    displayProgress("Open this directory in IntelliJ IDEA, Atom or VS Code.");
    displayProgress(
        "See ${destDirectory.path}${path_lib.separator}README.md for more information.");

    return 0;
  }

  Uri _packageUri(Directory conduitLocation, String packageDir) {
    return Directory(join(conduitLocation.path, '..', packageDir)).uri;
  }

  bool shouldIncludeItem(FileSystemEntity entity) {
    var ignoreFiles = [
      "packages",
      "pubspec.lock",
      "Dart_Packages.xml",
      "workspace.xml",
      "tasks.xml",
      "vcs.xml",
    ];

    var hiddenFilesToKeep = [
      ".gitignore",
      ".travis.yml",
      "analysis_options.yaml"
    ];

    var lastComponent = entity.uri.pathSegments.last;
    if (lastComponent.isEmpty) {
      lastComponent =
          entity.uri.pathSegments[entity.uri.pathSegments.length - 2];
    }

    if (lastComponent.startsWith(".") &&
        !hiddenFilesToKeep.contains(lastComponent)) {
      return false;
    }

    if (ignoreFiles.contains(lastComponent)) {
      return false;
    }

    return true;
  }

  void interpretContentFile(String? projectName, Directory destinationDirectory,
      FileSystemEntity sourceFileEntity) {
    if (shouldIncludeItem(sourceFileEntity)) {
      if (sourceFileEntity is Directory) {
        copyDirectory(projectName, destinationDirectory, sourceFileEntity);
      } else if (sourceFileEntity is File) {
        copyFile(projectName!, destinationDirectory, sourceFileEntity);
      }
    }
  }

  void copyDirectory(String? projectName, Directory destinationParentDirectory,
      Directory sourceDirectory) {
    var sourceDirectoryName = sourceDirectory
        .uri.pathSegments[sourceDirectory.uri.pathSegments.length - 2];
    var destDir = Directory(
        path_lib.join(destinationParentDirectory.path, sourceDirectoryName));

    destDir.createSync();

    sourceDirectory.listSync().forEach((f) {
      interpretContentFile(projectName, destDir, f);
    });
  }

  void copyFile(
      String projectName, Directory destinationDirectory, File sourceFile) {
    var path = path_lib.join(
        destinationDirectory.path, fileNameForFile(projectName, sourceFile));
    var contents = sourceFile.readAsStringSync();

    contents = contents.replaceAll("wildfire", projectName);
    contents =
        contents.replaceAll("Wildfire", camelCaseFromSnakeCase(projectName));

    var outputFile = File(path);
    outputFile.createSync();
    outputFile.writeAsStringSync(contents);
  }

  String fileNameForFile(String projectName, File sourceFile) {
    return sourceFile.uri.pathSegments.last
        .replaceFirst("wildfire", projectName);
  }

  Directory destinationDirectoryFromPath(String pathString) {
    if (pathString.startsWith("/")) {
      return Directory(pathString);
    }
    var currentDirPath = join(Directory.current.path, pathString);

    return Directory(currentDirPath);
  }

  void createProjectSpecificFiles(String directoryPath) {
    displayProgress("Generating config.yaml from config.src.yaml.");
    var configSrcPath = File(path_lib.join(directoryPath, "config.src.yaml"));
    configSrcPath
        .copySync(File(path_lib.join(directoryPath, "config.yaml")).path);
  }

  bool addDependencyOverridesToPackage(
      String packageDirectoryPath, Map<String, Uri> overrides) {
    var pubspecFile = File(path_lib.join(packageDirectoryPath, "pubspec.yaml"));
    var contents = pubspecFile.readAsStringSync();

    bool valid = true;

    final overrideBuffer = StringBuffer();
    overrideBuffer.writeln("dependency_overrides:");
    overrides.forEach((packageName, location) {
      var path = location.toFilePath(windows: Platform.isWindows);

      valid &= _testPackagePath(path, packageName);
      overrideBuffer.writeln("  $packageName:");
      overrideBuffer.writeln(
          "    path:  ${location.toFilePath(windows: Platform.isWindows)}");
    });

    pubspecFile.writeAsStringSync("$contents\n$overrideBuffer");

    return valid;
  }

  void copyProjectFiles(Directory destinationDirectory,
      Directory sourceDirectory, String? projectName) {
    displayInfo(
        "Copying template files to project directory (${destinationDirectory.path})...");
    try {
      destinationDirectory.createSync();

      Directory(sourceDirectory.path).listSync().forEach((f) {
        displayProgress("Copying contents of ${f.path}");
        interpretContentFile(projectName, destinationDirectory, f);
      });
    } catch (e) {
      destinationDirectory.deleteSync(recursive: true);
      displayError("$e");
      rethrow;
    }
  }

  bool isSnakeCase(String string) {
    var expr = RegExp("^[a-z][a-z0-9_]*\$");
    return expr.hasMatch(string);
  }

  String camelCaseFromSnakeCase(String string) {
    return string.split("_").map((str) {
      var firstChar = str.substring(0, 1);
      var remainingString = str.substring(1, str.length);
      return firstChar.toUpperCase() + remainingString;
    }).join("");
  }

  Future<int> fetchProjectDependencies(Directory workingDirectory,
      {bool offline = false}) async {
    var args = ["get"];
    if (offline) {
      args.add("--offline");
    }

    try {
      final cmd = Platform.isWindows ? "pub.bat" : "pub";
      var process = await Process.start(cmd, args,
              workingDirectory: workingDirectory.absolute.path,
              runInShell: true)
          .timeout(const Duration(seconds: 60));
      process.stdout
          .transform(utf8.decoder)
          .listen((output) => outputSink.write(output));
      process.stderr
          .transform(utf8.decoder)
          .listen((output) => outputSink.write(output));

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        throw CLIException(
            "If you are offline, try using `pub get --offline`.");
      }

      return exitCode;
    } on TimeoutException {
      displayError(
          "Timed out fetching dependencies. Reconnect to the internet or use `pub get --offline`.");
      rethrow;
    }
  }

  @override
  String get usage {
    return "${super.usage} <project_name>";
  }

  @override
  String get name {
    return "create";
  }

  @override
  String get detailedDescription {
    return "This command will use a template from the conduit package determined by either "
        "git-url (and git-ref), path-source or version. If none of these "
        "are specified, the most recent version on pub.dartlang.org is used.";
  }

  @override
  String get description {
    return "Creates Conduit applications from templates.";
  }

  /// check if a path exists sync.
  bool _exists(String path) {
    return Directory(path).existsSync();
  }

  /// test if the given package dir exists in the test path
  bool _testPackagePath(String testPath, String packageName) {
    String packagePath = _truepath(testPath);
    if (!_exists(packagePath)) {
      displayError(
          "The source for path '$packageName' doesn't exists. Expected to find it at '$packagePath'");
      return false;
    }
    return true;
  }

  String _truepath(String path) => canonicalize(absolute(path));
}

class CLITemplateList extends CLICommand with CLIConduitGlobal {
  @override
  Future<int> handle() async {
    final templateRootDirectory = Directory.fromUri(templateDirectory ?? Uri());
    final templateDirectories = await templateRootDirectory
        .list()
        .where((fse) => fse is Directory)
        .map((fse) => fse as Directory)
        .toList();
    final templateDescriptions =
        await Future.wait(templateDirectories.map(_templateDescription));
    displayInfo("Available templates:");
    displayProgress("");

    templateDescriptions.forEach(displayProgress);

    return 0;
  }

  @override
  String get name {
    return "list-templates";
  }

  @override
  String get description {
    return "List Conduit application templates.";
  }

  Future<String> _templateDescription(Directory templateDirectory) async {
    final name = templateDirectory
        .uri.pathSegments[templateDirectory.uri.pathSegments.length - 2];
    final pubspecContents =
        await File.fromUri(templateDirectory.uri.resolve("pubspec.yaml"))
            .readAsString();
    final pubspecDefinition = loadYaml(pubspecContents);

    return "$name | ${pubspecDefinition["description"]}";
  }
}

class CLIConduitGlobal {
  PubCache pub = PubCache();

  PackageRef? get conduitPackageRef {
    var apps = pub.getGlobalApplications();
    if (apps.isEmpty) {
      return null;
    }
    return apps
        .firstWhere((app) => app.name == "conduit")
        .getDefiningPackageRef();
  }

  Uri? get templateDirectory {
    return conduitPackageRef?.resolve()?.location.uri.resolve("templates/");
  }

  Uri? getTemplateLocation(String templateName) {
    return templateDirectory?.resolve("$templateName/");
  }
}
