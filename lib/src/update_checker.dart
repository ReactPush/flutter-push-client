import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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

    return update;
  }
}

