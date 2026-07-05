import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart scripts/release.dart <new_version>');
    print('Example: dart scripts/release.dart 1.0.1+2');
    exit(1);
  }

  final newVersion = args[0];
  final pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    print('pubspec.yaml not found! Run this script from the project root.');
    exit(1);
  }

  String content = pubspecFile.readAsStringSync();
  final versionRegex = RegExp(r'^version:\s+.*$', multiLine: true);

  if (!versionRegex.hasMatch(content)) {
    print('Could not find version line in pubspec.yaml');
    exit(1);
  }

  content = content.replaceFirst(versionRegex, 'version: $newVersion');
  pubspecFile.writeAsStringSync(content);

  print('Updated pubspec.yaml to version: $newVersion');

  final versionTag = 'v$newVersion';

  print('Committing and tagging as $versionTag...');

  _runCommand('git', ['add', 'pubspec.yaml']);
  _runCommand('git', ['commit', '-m', 'chore: release $versionTag']);
  _runCommand('git', ['tag', versionTag]);

  print('Pushing to origin...');
  _runCommand('git', ['push', 'origin', 'HEAD']);
  _runCommand('git', ['push', 'origin', versionTag]);

  print('=============================================');
  print('Release $versionTag triggered successfully!');
  print('GitHub Actions should now build and publish it.');
  print('=============================================');
}

void _runCommand(String executable, List<String> arguments) {
  final result = Process.runSync(executable, arguments);
  if (result.exitCode != 0) {
    print('Error running command: $executable ${arguments.join(' ')}');
    print(result.stdout);
    print(result.stderr);
    exit(1);
  }
}
