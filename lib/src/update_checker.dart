import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'signature_verifier.dart';
import 'flutter_push.dart';

class UpdateChecker {
  final FlutterPush flutterPush;

  UpdateChecker(this.flutterPush);

  Future<Map<String, dynamic>?> check() async {
    String platform = 'unknown';
    
    if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isIOS) {
      platform = 'ios';
    }

    final response = await http.post(
      Uri.parse('${flutterPush.apiUrl}/api/updates/check'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': flutterPush.apiKey,
      },
      body: jsonEncode({
        'appVersion': flutterPush.appVersion,
        'platform': platform,
        'deviceId': await flutterPush.getDeviceIdAsync(),
        'userId': flutterPush.userId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Update check failed: ${response.statusCode} ${response.reasonPhrase}');
    }

    final update = jsonDecode(response.body) as Map<String, dynamic>;

    // Verify signature if available
    if (update['hasUpdate'] == true && 
        update['publicKey'] != null && 
        update['signature'] != null) {
      try {
        final isValid = await verifyUpdateSignature(
          update['publicKey'] as String,
          update,
          update['signature'] as String,
        );

        if (!isValid) {
          print('FlutterPush: Update signature verification failed');
          throw Exception('Update signature verification failed. Update may be compromised.');
        }

        print('FlutterPush: Update signature verified successfully');
      } catch (error) {
        print('FlutterPush: Error verifying update signature: $error');
        throw Exception('Update signature verification failed: $error');
      }
    } else if (update['hasUpdate'] == true && 
               update['publicKey'] != null && 
               update['signature'] == null) {
      // App has public key but update is not signed - this is a security issue
      print('FlutterPush: App requires signed updates but update is not signed');
      throw Exception('Update is not signed. This app requires signed updates.');
    }

    return update;
  }
}

