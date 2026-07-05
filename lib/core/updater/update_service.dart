import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class GitHubRelease {
  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final List<GitHubAsset> assets;

  GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      htmlUrl: json['html_url'] ?? '',
      assets: (json['assets'] as List?)
              ?.map((e) => GitHubAsset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String get versionString => tagName.startsWith('v') ? tagName.substring(1) : tagName;
}

class GitHubAsset {
  final String name;
  final String browserDownloadUrl;

  GitHubAsset({
    required this.name,
    required this.browserDownloadUrl,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'] ?? '',
      browserDownloadUrl: json['browser_download_url'] ?? '',
    );
  }
}

class UpdateService {
  final String repoOwner = 'mgarg123';
  final String repoName = '1pass';
  final Dio _dio = Dio();

  Future<GitHubRelease?> checkForUpdates() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ),
      );

      if (response.statusCode == 200) {
        final release = GitHubRelease.fromJson(response.data);
        final isNewer = await _isNewerVersion(release.versionString);
        if (isNewer) {
          return release;
        }
      }
    } catch (e) {
      print('Failed to check for updates: $e');
    }
    return null;
  }

  Future<bool> _isNewerVersion(String releaseVersion) async {
    final packageInfo = await PackageInfo.fromPlatform();
    // Use version without build number for comparison, or both.
    // Assuming format is X.Y.Z or X.Y.Z+B
    final currentParts = packageInfo.version.split('+')[0].split('.');
    final releaseParts = releaseVersion.split('+')[0].split('.');

    for (var i = 0; i < currentParts.length && i < releaseParts.length; i++) {
      final current = int.tryParse(currentParts[i]) ?? 0;
      final release = int.tryParse(releaseParts[i]) ?? 0;
      if (release > current) return true;
      if (release < current) return false;
    }
    
    // Check build number if versions are same
    final currentBuild = packageInfo.buildNumber.isNotEmpty ? int.tryParse(packageInfo.buildNumber) ?? 0 : 0;
    var releaseBuild = 0;
    if (releaseVersion.contains('+')) {
       releaseBuild = int.tryParse(releaseVersion.split('+')[1]) ?? 0;
    }
    
    return releaseBuild > currentBuild;
  }

  String? getDownloadUrlForPlatform(GitHubRelease release) {
    String assetPrefix = '';
    if (Platform.isAndroid) assetPrefix = 'OnePass-Android-';
    if (Platform.isMacOS) assetPrefix = 'OnePass-macOS-';
    if (Platform.isWindows) assetPrefix = 'OnePass-Windows-';
    // iOS will just use the release page URL

    for (var asset in release.assets) {
      if (asset.name.startsWith(assetPrefix)) {
        return asset.browserDownloadUrl;
      }
    }
    return null;
  }
}
