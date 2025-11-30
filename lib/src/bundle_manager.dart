import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'flutter_push.dart';

class BundleManager {
  final FlutterPush flutterPush;
  late String bundleDirectory;
  static const String bundlePathKey = '@FlutterPush:currentBundlePath';
  static const String bundleVersionKey = '@FlutterPush:currentBundleVersion';

  BundleManager(this.flutterPush) {
    _initializeDirectory();
  }

  Future<void> _initializeDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    bundleDirectory = path.join(appDir.path, 'FlutterPushBundles');
    final dir = Directory(bundleDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> ensureDirectory() async {
    await _initializeDirectory();
  }

  Future<String> downloadBundle(Map<String, dynamic> update) async {
    await ensureDirectory();
    
    // Check if we have a zip file (preferred) or separate bundle/assets URLs
    if (update['zipUrl'] != null) {
      return await downloadAndExtractZip(update);
    } else if (update['bundleUrl'] != null) {
      return await downloadSeparateBundle(update);
    } else {
      throw Exception('Neither ZipUrl nor BundleUrl is provided in update');
    }
  }

  Future<String> downloadAndExtractZip(Map<String, dynamic> update) async {
    if (update['zipUrl'] == null) {
      throw Exception('ZipUrl is missing in update');
    }

    final versionDir = Directory(
      path.join(bundleDirectory, 'version_${update['version']}_${DateTime.now().millisecondsSinceEpoch}'),
    );
    await versionDir.create(recursive: true);

    final zipPath = path.join(versionDir.path, 'update.zip');
    final extractedPath = path.join(versionDir.path, 'extracted');

    print('Downloading zip from: ${update['zipUrl']}');
    print('Saving to: $zipPath');

    try {
      // Download zip file
      final response = await http.get(Uri.parse(update['zipUrl'] as String));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download zip: HTTP ${response.statusCode}. URL: ${update['zipUrl']}');
      }

      // Save zip file
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(response.bodyBytes);

      print('Zip downloaded successfully: $zipPath');

      // Extract zip file
      await extractZip(zipPath, extractedPath);

      // Remove zip file after extraction
      await zipFile.delete();

      // Find bundle.js in extracted directory
      final bundlePath = await findBundleInExtracted(extractedPath);
      
      if (bundlePath == null) {
        throw Exception('bundle.js not found in extracted zip file');
      }

      print('Bundle found at: $bundlePath');

      // Find assets directory
      final assetsPath = path.join(extractedPath, 'assets');
      final assetsDir = Directory(assetsPath);
      if (await assetsDir.exists()) {
        print('Assets found at: $assetsPath');
      }

      // Store the bundle path so native code can load it on next app start
      await storeBundlePath(bundlePath, update['version'] as String);

      return bundlePath;
    } catch (error) {
      print('Zip download/extraction error: $error');
      // Clean up on error
      try {
        if (await versionDir.exists()) {
          await versionDir.delete(recursive: true);
        }
      } catch (cleanupError) {
        // Ignore cleanup errors
      }
      
      if (error.toString().contains('404')) {
        throw Exception('Zip not found (404). Please check that the zip URL is correct: ${update['zipUrl']}');
      }
      throw Exception('Failed to download/extract zip: $error. URL: ${update['zipUrl']}');
    }
  }

  Future<String> downloadSeparateBundle(Map<String, dynamic> update) async {
    if (update['bundleUrl'] == null) {
      throw Exception('BundleUrl is missing in update');
    }
    
    final bundleFileName = 'bundle_${update['version']}_${DateTime.now().millisecondsSinceEpoch}.js';
    final bundlePath = path.join(bundleDirectory, bundleFileName);

    print('Downloading bundle from: ${update['bundleUrl']}');
    print('Saving to: $bundlePath');

    // Download bundle.js
    try {
      final response = await http.get(Uri.parse(update['bundleUrl'] as String));

      if (response.statusCode != 200) {
        throw Exception('Failed to download bundle: HTTP ${response.statusCode}. URL: ${update['bundleUrl']}');
      }

      // Save bundle file
      final bundleFile = File(bundlePath);
      await bundleFile.writeAsBytes(response.bodyBytes);

      print('Bundle downloaded successfully: $bundlePath');
      
      // Store the bundle path so native code can load it on next app start
      await storeBundlePath(bundlePath, update['version'] as String);
    } catch (error) {
      print('Bundle download error: $error');
      if (error.toString().contains('404')) {
        throw Exception('Bundle not found (404). Please check that the bundle URL is correct: ${update['bundleUrl']}');
      }
      throw Exception('Failed to download bundle: $error. URL: ${update['bundleUrl']}');
    }

    // Download assets if available
    if (update['assetsUrl'] != null) {
      await downloadAssets(update['assetsUrl'] as String, update['version'] as String);
    }

    return bundlePath;
  }

  Future<void> extractZip(String zipPath, String extractPath) async {
    try {
      final zipFile = File(zipPath);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final extractDir = Directory(extractPath);
      if (!await extractDir.exists()) {
        await extractDir.create(recursive: true);
      }

      for (final file in archive) {
        final filename = path.join(extractPath, file.name);
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        } else {
          await Directory(filename).create(recursive: true);
        }
      }

      print('Zip extracted to: $extractPath');
    } catch (error) {
      throw Exception('Zip extraction failed: $error');
    }
  }

  Future<String?> findBundleInExtracted(String extractedPath) async {
    // Look for bundle.js in the extracted directory
    final dir = Directory(extractedPath);
    if (!await dir.exists()) {
      return null;
    }

    // Check root level
    final rootBundle = File(path.join(extractedPath, 'bundle.js'));
    if (await rootBundle.exists()) {
      return rootBundle.path;
    }
    
    // Check subdirectories
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && path.basename(entity.path) == 'bundle.js') {
        return entity.path;
      }
    }
    
    return null;
  }

  Future<void> downloadAssets(String assetsUrl, String version) async {
    final assetsDirectory = path.join(bundleDirectory, 'assets_$version');
    final assetsDir = Directory(assetsDirectory);
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }

    // In a real implementation, you would:
    // 1. Fetch the assets manifest from assetsUrl
    // 2. Download each asset file
    // 3. Store them in the assets directory
    
    // For now, this is a placeholder
    print('Assets download for version $version would be implemented here');
  }

  Future<String?> getLocalBundlePath(String version) async {
    await ensureDirectory();
    final dir = Directory(bundleDirectory);
    if (!await dir.exists()) {
      return null;
    }

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.contains(version)) {
        return entity.path;
      }
    }
    
    return null;
  }

  Future<void> clearOldBundles(String keepVersion) async {
    try {
      await ensureDirectory();
      final dir = Directory(bundleDirectory);
      if (!await dir.exists()) {
        return;
      }

      await for (final entity in dir.list()) {
        if (entity is File && !entity.path.contains(keepVersion)) {
          await entity.delete();
        } else if (entity is Directory && !entity.path.contains(keepVersion)) {
          await entity.delete(recursive: true);
        }
      }
    } catch (error) {
      print('Error clearing old bundles: $error');
    }
  }

  /// Store the bundle path so native code can load it on app start
  Future<void> storeBundlePath(String bundlePath, String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(bundlePathKey, bundlePath);
      await prefs.setString(bundleVersionKey, version);
      
      print('Stored bundle path: $bundlePath for version $version');
    } catch (error) {
      print('Error storing bundle path: $error');
      // Don't throw - this is not critical for the download to succeed
    }
  }

  /// Get the currently stored bundle path
  Future<String?> getStoredBundlePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(bundlePathKey);
    } catch (error) {
      print('Error getting stored bundle path: $error');
      return null;
    }
  }

  /// Clear the stored bundle path (revert to default bundle)
  Future<void> clearStoredBundlePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(bundlePathKey);
      await prefs.remove(bundleVersionKey);
      
      print('Cleared stored bundle path');
    } catch (error) {
      print('Error clearing stored bundle path: $error');
    }
  }
}

