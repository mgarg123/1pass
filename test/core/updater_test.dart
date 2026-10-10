import 'package:flutter_test/flutter_test.dart';
import 'package:one_pass/core/updater/update_service.dart';

void main() {
  group('UpdateService & GitHubRelease tests', () {
    test('cleanVersion strips build number and leading v', () {
      final r1 = GitHubRelease(
        tagName: 'v1.2.0+18',
        name: 'Release 1.2.0',
        body: 'Notes',
        htmlUrl: 'https://example.com',
        assets: [],
      );
      expect(r1.cleanVersion, '1.2.0');
      expect(r1.displayTag, 'v1.2.0');

      final r2 = GitHubRelease(
        tagName: '1.3.1+99',
        name: 'Release 1.3.1',
        body: '',
        htmlUrl: 'https://example.com',
        assets: [],
      );
      expect(r2.cleanVersion, '1.3.1');
      expect(r2.displayTag, 'v1.3.1');

      final r3 = GitHubRelease(
        tagName: 'v2.0.0',
        name: 'Major Release',
        body: '',
        htmlUrl: 'https://example.com',
        assets: [],
      );
      expect(r3.cleanVersion, '2.0.0');
      expect(r3.displayTag, 'v2.0.0');
    });

    test('GitHubAsset parses size from JSON correctly', () {
      final asset = GitHubAsset.fromJson({
        'name': 'OnePass-Android-v1.2.0.apk',
        'browser_download_url': 'https://download.example.com/app.apk',
        'size': 45678901,
      });

      expect(asset.name, 'OnePass-Android-v1.2.0.apk');
      expect(asset.browserDownloadUrl, 'https://download.example.com/app.apk');
      expect(asset.size, 45678901);
    });
  });
}
