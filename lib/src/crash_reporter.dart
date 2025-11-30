import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'flutter_push.dart';

class CrashReporter {
  final FlutterPush flutterPush;
  final List<Map<String, dynamic>> breadcrumbs = [];
  final int maxBreadcrumbs = 50;
  String? currentUpdateId;
  String? currentBundleVersion;

  CrashReporter(this.flutterPush);

  /// Set the current update ID and bundle version
  void setCurrentUpdate(String updateId, String bundleVersion) {
    currentUpdateId = updateId;
    currentBundleVersion = bundleVersion;
  }

  /// Add a breadcrumb (event that happened before crash)
  void addBreadcrumb(String message, [Map<String, dynamic>? data]) {
    final breadcrumb = {
      'message': message,
      'data': data ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    breadcrumbs.add(breadcrumb);
    
    // Keep only the last N breadcrumbs
    if (breadcrumbs.length > maxBreadcrumbs) {
      breadcrumbs.removeAt(0);
    }
  }

  /// Clear breadcrumbs
  void clearBreadcrumbs() {
    breadcrumbs.clear();
  }

  /// Get device information including model, OS version, etc.
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      final deviceInfo = <String, dynamic>{
        'appVersion': packageInfo.version,
        'bundleVersion': currentBundleVersion ?? packageInfo.version,
      };

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfo['platform'] = 'android';
        deviceInfo['osVersion'] = androidInfo.version.release;
        deviceInfo['model'] = androidInfo.model;
        deviceInfo['brand'] = androidInfo.brand;
        deviceInfo['manufacturer'] = androidInfo.manufacturer;
        deviceInfo['systemName'] = 'Android';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfo['platform'] = 'ios';
        deviceInfo['osVersion'] = iosInfo.systemVersion;
        deviceInfo['model'] = iosInfo.model;
        deviceInfo['systemName'] = 'iOS';
        deviceInfo['deviceName'] = iosInfo.name;
      } else {
        deviceInfo['platform'] = 'unknown';
        deviceInfo['systemName'] = Platform.operatingSystem;
      }

      return deviceInfo;
    } catch (error) {
      print('Failed to get device info: $error');
      return {
        'platform': Platform.operatingSystem,
        'appVersion': flutterPush.appVersion,
        'bundleVersion': currentBundleVersion ?? flutterPush.appVersion,
      };
    }
  }

  /// Report a crash/error to the server
  Future<bool> reportCrash(dynamic error, [Map<String, dynamic>? options]) async {
    try {
      await flutterPush.getDeviceIdAsync();
      
      final deviceInfo = await getDeviceInfo();
      
      final crashReport = {
        'updateId': options?['updateId'] ?? currentUpdateId,
        'deviceId': flutterPush.deviceId,
        'platform': Platform.operatingSystem,
        'appVersion': deviceInfo['appVersion'] ?? flutterPush.appVersion,
        'bundleVersion': options?['bundleVersion'] ?? 
                        deviceInfo['bundleVersion'] ?? 
                        currentBundleVersion ?? 
                        flutterPush.appVersion,
        'errorType': options?['errorType'] ?? getErrorType(error),
        'errorMessage': options?['errorMessage'] ?? getErrorMessage(error),
        'stackTrace': options?['stackTrace'] ?? getStackTrace(error),
        'deviceInfo': jsonEncode(deviceInfo),
        'userInfo': options?['userInfo'] != null ? jsonEncode(options!['userInfo']) : null,
        'breadcrumbs': breadcrumbs.isNotEmpty ? jsonEncode(breadcrumbs) : null,
        'severity': options?['severity'] ?? 'error',
        'occurredAt': options?['occurredAt'] ?? DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('${flutterPush.apiUrl}/api/crash-reports'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': flutterPush.apiKey,
        },
        body: jsonEncode(crashReport),
      );

      if (response.statusCode != 200) {
        print('Failed to report crash: ${response.statusCode} ${response.body}');
        return false;
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      print('Crash reported successfully: ${result['id']}');
      
      // Clear breadcrumbs after successful report
      clearBreadcrumbs();
      
      return true;
    } catch (error) {
      print('Error reporting crash: $error');
      return false;
    }
  }

  /// Report a JavaScript error
  Future<bool> reportJavaScriptError(dynamic error, [Map<String, dynamic>? userInfo]) async {
    return await reportCrash(error, {
      'errorType': 'JavaScriptError',
      if (userInfo != null) 'userInfo': userInfo,
    });
  }

  /// Report a native error
  Future<bool> reportNativeError(dynamic error, [Map<String, dynamic>? userInfo]) async {
    return await reportCrash(error, {
      'errorType': 'NativeError',
      if (userInfo != null) 'userInfo': userInfo,
    });
  }

  /// Report a custom error
  Future<bool> reportCustomError(
    String message,
    String errorType,
    String? stackTrace,
    [Map<String, dynamic>? userInfo]
  ) async {
    final error = Exception(message);
    return await reportCrash(error, {
      'errorType': errorType,
      'stackTrace': stackTrace,
      if (userInfo != null) 'userInfo': userInfo,
    });
  }

  /// Get error type from error object
  String getErrorType(dynamic error) {
    if (error is TypeError) return 'TypeError';
    if (error is FormatException) return 'FormatException';
    if (error is ArgumentError) return 'ArgumentError';
    if (error is StateError) return 'StateError';
    if (error is RangeError) return 'RangeError';
    if (error is Exception) return 'Exception';
    return 'Error';
  }

  /// Get error message from error object
  String getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString();
    }
    if (error is String) {
      return error;
    }
    return 'Unknown error';
  }

  /// Get stack trace from error object
  String? getStackTrace(dynamic error) {
    if (error is Error) {
      return error.stackTrace?.toString();
    }
    return null;
  }
}

