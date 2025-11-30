import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'update_checker.dart';
import 'bundle_manager.dart';
import 'crash_reporter.dart';

const String deviceIdStorageKey = '@FlutterPush:deviceId';

class FlutterPush {
  final String apiKey;
  final String apiUrl;
  final String appVersion;
  String? deviceId;
  final String? userId;
  
  // Callbacks
  final Function(Map<String, dynamic>)? onUpdateAvailable;
  final Function(Map<String, dynamic>)? onUpdateDownloaded;
  final Function(dynamic)? onError;
  final bool enableCrashReporting;

  late final UpdateChecker updateChecker;
  late final BundleManager bundleManager;
  late final CrashReporter crashReporter;

  FlutterPush({
    required this.apiKey,
    this.apiUrl = 'http://localhost:5000',
    required this.appVersion,
    this.userId,
    this.onUpdateAvailable,
    this.onUpdateDownloaded,
    this.onError,
    this.enableCrashReporting = true,
    String? deviceId,
  }) {
    // Initialize after constructor body starts
    updateChecker = UpdateChecker(this);
    bundleManager = BundleManager(this);
    crashReporter = CrashReporter(this);
    
    if (deviceId != null) {
      this.deviceId = deviceId;
      _deviceIdFuture = Future.value(deviceId);
    } else {
      _deviceIdFuture = initializeDeviceId();
    }

    // Setup crash reporting if enabled
    if (enableCrashReporting) {
      // Note: Flutter doesn't have global error handlers like React Native
      // You would need to set up error handlers in your app's main function
    }
  }

  Future<String>? _deviceIdFuture;

  /// Generate a unique device ID
  String generateDeviceId() {
    const uuid = Uuid();
    return 'device_${uuid.v4()}';
  }

  /// Initialize device ID from storage or generate a new one
  Future<String> initializeDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDeviceId = prefs.getString(deviceIdStorageKey);
      
      if (storedDeviceId != null) {
        deviceId = storedDeviceId;
        print('FlutterPush: Loaded existing device ID: $storedDeviceId');
        return storedDeviceId;
      }
      
      // Generate new device ID if none exists
      final newDeviceId = generateDeviceId();
      await prefs.setString(deviceIdStorageKey, newDeviceId);
      deviceId = newDeviceId;
      print('FlutterPush: Generated new device ID: $newDeviceId');
      return newDeviceId;
    } catch (error) {
      print('FlutterPush: Failed to initialize device ID: $error');
      // Fallback to generating a temporary ID (won't persist)
      final fallbackId = generateDeviceId();
      deviceId = fallbackId;
      return fallbackId;
    }
  }

  /// Ensure device ID is initialized before use
  Future<String> ensureDeviceId() async {
    if (deviceId != null) {
      return deviceId!;
    }
    return await _deviceIdFuture ?? await initializeDeviceId();
  }

  /// Check for available updates
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // Ensure device ID is initialized before checking for updates
      await ensureDeviceId();
      final update = await updateChecker.check();
      
      if (update != null && update['hasUpdate'] == true) {
        if (onUpdateAvailable != null) {
          onUpdateAvailable!(update);
        }
        return update;
      }
      
      return null;
    } catch (error) {
      if (onError != null) {
        onError!(error);
      }
      rethrow;
    }
  }

  /// Download an update
  Future<String> downloadUpdate(Map<String, dynamic> update) async {
    try {
      final bundlePath = await bundleManager.downloadBundle(update);
      
      // Track current update for crash reporting
      if (update['updateId'] != null) {
        crashReporter.setCurrentUpdate(
          update['updateId'].toString(),
          update['version']?.toString() ?? appVersion,
        );
      }
      
      if (onUpdateDownloaded != null) {
        final downloadedUpdate = Map<String, dynamic>.from(update);
        downloadedUpdate['localBundlePath'] = bundlePath;
        onUpdateDownloaded!(downloadedUpdate);
      }
      
      return bundlePath;
    } catch (error) {
      // Report download errors
      crashReporter.reportJavaScriptError(error, {
        'context': 'downloadUpdate',
        'updateVersion': update['version'],
      }).catchError((err) {
        print('Failed to report download error: $err');
        return false;
      });
      
      if (onError != null) {
        onError!(error);
      }
      rethrow;
    }
  }

  /// Sync updates (check and download automatically)
  Future<void> sync({
    String checkFrequency = 'ON_APP_START',
    String installMode = 'ON_NEXT_RESTART',
  }) async {
    try {
      final update = await checkForUpdate();
      
      if (update != null) {
        if (update['isMandatory'] == true || installMode == 'IMMEDIATE') {
          await downloadUpdate(update);
          if (installMode == 'IMMEDIATE') {
            // Note: Flutter doesn't have a built-in restart mechanism
            // You would need to implement this using platform-specific code
            print('FlutterPush: Immediate restart not implemented. Please restart the app manually.');
          }
        } else {
          await downloadUpdate(update);
        }
      }
    } catch (error) {
      if (onError != null) {
        onError!(error);
      }
    }
  }

  /// Get current version
  String getCurrentVersion() {
    return appVersion;
  }

  /// Get device ID (synchronous - may return null if not initialized)
  String? getDeviceId() {
    return deviceId;
  }

  /// Get device ID (async version that ensures it's initialized)
  Future<String> getDeviceIdAsync() async {
    return await ensureDeviceId();
  }

  /// Reset device ID (generates a new one)
  Future<String> resetDeviceId() async {
    try {
      final newDeviceId = generateDeviceId();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(deviceIdStorageKey, newDeviceId);
      deviceId = newDeviceId;
      print('FlutterPush: Device ID reset to: $newDeviceId');
      return newDeviceId;
    } catch (error) {
      print('FlutterPush: Failed to reset device ID: $error');
      rethrow;
    }
  }

  /// Report a crash/error
  Future<bool> reportCrash(dynamic error, [Map<String, dynamic>? options]) async {
    return await crashReporter.reportCrash(error, options);
  }

  /// Report a JavaScript error
  Future<bool> reportJavaScriptError(dynamic error, [Map<String, dynamic>? userInfo]) async {
    return await crashReporter.reportJavaScriptError(error, userInfo);
  }

  /// Report a native error
  Future<bool> reportNativeError(dynamic error, [Map<String, dynamic>? userInfo]) async {
    return await crashReporter.reportNativeError(error, userInfo);
  }

  /// Report a custom error
  Future<bool> reportCustomError(
    String message,
    String errorType,
    String? stackTrace,
    [Map<String, dynamic>? userInfo]
  ) async {
    return await crashReporter.reportCustomError(message, errorType, stackTrace, userInfo);
  }

  /// Add a breadcrumb (event that happened before crash)
  void addBreadcrumb(String message, [Map<String, dynamic>? data]) {
    crashReporter.addBreadcrumb(message, data);
  }

  /// Get the crash reporter instance
  CrashReporter getCrashReporter() {
    return crashReporter;
  }

  /// Get the downloaded bundle URL/path
  Future<String?> getDownloadedBundleURL() async {
    try {
      final bundlePath = await bundleManager.getStoredBundlePath();
      
      if (bundlePath != null) {
        // Verify the file still exists
        final file = File(bundlePath);
        if (await file.exists()) {
          return bundlePath;
        } else {
          // File doesn't exist, clear the stored path
          print('FlutterPush: Stored bundle path does not exist, clearing it');
          await bundleManager.clearStoredBundlePath();
          return null;
        }
      }
      
      return null;
    } catch (error) {
      print('FlutterPush: Error getting downloaded bundle URL: $error');
      return null;
    }
  }

  /// Get bundle manager instance for advanced usage
  BundleManager getBundleManager() {
    return bundleManager;
  }
}

