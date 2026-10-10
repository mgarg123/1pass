import 'dart:io';

void main(List<String> args) {
  final pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    print('❌ pubspec.yaml not found! Run this script from the project root.');
    exit(1);
  }

  String content = pubspecFile.readAsStringSync();
  final versionRegex = RegExp(r'^version:\s+([^\s#]+)', multiLine: true);
  final match = versionRegex.firstMatch(content);

  if (match == null) {
    print('❌ Could not find version line in pubspec.yaml');
    exit(1);
  }

  final bool forceRetry = args.contains('--retry') || args.contains('--force') || args.contains('-f');
  final version = match.group(1)!.trim().replaceAll("'", '').replaceAll('"', '');
  final versionTag = 'v$version';

  print('📦 Target version in pubspec.yaml: $version');
  print('🏷️  Release tag: $versionTag');

  // Check if tag already exists
  final localTagCheck = Process.runSync('git', ['rev-parse', versionTag]);
  if (localTagCheck.exitCode == 0) {
    bool doRetry = forceRetry;
    if (!doRetry) {
      stdout.write('⚠️  Tag $versionTag already exists. Overwrite/re-publish to retry the build? [y/N]: ');
      final input = stdin.readLineSync()?.trim().toLowerCase();
      if (input == 'y' || input == 'yes') {
        doRetry = true;
      } else {
        print('❌ Cancelled. Please bump version in pubspec.yaml before releasing.');
        exit(1);
      }
    }

    if (doRetry) {
      print('🔄 Removing existing tag $versionTag locally and remotely...');
      Process.runSync('git', ['tag', '-d', versionTag]);
      Process.runSync('git', ['push', 'origin', '--delete', versionTag]);
    }
  }

  print('🚀 Staging and committing changes...');
  _runCommand('git', ['add', '.']);
  _runCommand('git', ['commit', '--allow-empty', '-m', 'chore: release $versionTag']);
  _runCommand('git', ['tag', versionTag]);

  print('⬆️  Pushing to origin...');
  _runCommand('git', ['push', 'origin', 'HEAD']);
  _runCommand('git', ['push', 'origin', versionTag]);

  print('=============================================');
  print('✅ Release $versionTag triggered successfully!');
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
