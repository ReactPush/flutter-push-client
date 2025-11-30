import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_push_client/flutter_push.dart';

// API Key for ReactPush
const String apiKey = 'iDB-tEiZKD9eF1VFJnLYaZhXi_hnTEeQ6Uy4uq0gmO0';
// Use localhost in debug mode, production URL otherwise
final String apiUrl = kDebugMode ? 'http://localhost:8686' : 'https://reactpush.com';
const String appVersion = '0.0.1';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlutterPush Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Initializing...';
  String _updateStatus = 'Checking for updates...';
  bool _isChecking = false;
  String _currentVersion = appVersion;
  FlutterPush? _flutterPush;

  @override
  void initState() {
    super.initState();
    _initializeFlutterPush();
  }

  void _initializeFlutterPush() {
    _flutterPush = FlutterPush(
      apiKey: apiKey,
      apiUrl: apiUrl,
      appVersion: appVersion,
      onUpdateAvailable: (update) {
        setState(() {
          _updateStatus = 'Update available: ${update['label'] ?? update['version']}';
        });
        _showUpdateDialog(update);
      },
      onUpdateDownloaded: (update) {
        setState(() {
          _updateStatus = 'Update downloaded! Please restart the app.';
        });
        _showRestartDialog();
      },
      onError: (error) {
        print('FlutterPush error: $error');
        setState(() {
          _updateStatus = 'Error: $error';
        });
        // Automatically report errors to crash reporting
        _flutterPush?.reportJavaScriptError(error, {
          'context': 'FlutterPush',
          'updateStatus': _updateStatus,
        }).catchError((err) => print('Failed to report error: $err'));
      },
      enableCrashReporting: true,
    );

    // Initialize device ID and check for updates on app start
    _initializeAndCheck();
  }

  Future<void> _initializeAndCheck() async {
    try {
      // Ensure device ID is initialized
      await _flutterPush?.getDeviceIdAsync();
      
      // Then check for updates
      _checkForUpdates();
    } catch (error) {
      print('Failed to initialize device ID: $error');
      // Still try to check for updates even if device ID init fails
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _updateStatus = 'Checking for updates...';
    });

    try {
      final update = await _flutterPush?.checkForUpdate();
      if (update != null) {
        setState(() {
          _updateStatus = 'Update available: ${update['label'] ?? update['version']}';
        });
      } else {
        setState(() {
          _updateStatus = 'You are on the latest version!';
        });
      }
    } catch (error) {
      setState(() {
        _updateStatus = 'Error: $error';
      });
      // Report check update errors
      _flutterPush?.reportJavaScriptError(error, {
        'context': 'checkForUpdates',
      }).catchError((err) => print('Failed to report error: $err'));
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  void _showUpdateDialog(Map<String, dynamic> update) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: Text('Version ${update['version']} is available. Would you like to download and install it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _downloadAndInstallUpdate(update);
              },
              child: const Text('Download & Install'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAndInstallUpdate(Map<String, dynamic> update) async {
    try {
      setState(() {
        _updateStatus = 'Downloading update...';
      });

      await _flutterPush?.downloadUpdate(update);
      
      setState(() {
        _updateStatus = 'Update downloaded! Please restart the app.';
      });

      _showRestartDialog();
    } catch (error) {
      setState(() {
        _updateStatus = 'Error: $error';
      });
      _showErrorDialog('Failed to download update: $error');
    }
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Installed'),
          content: const Text('The update has been downloaded. Please restart the app to apply it.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _testButton() {
    // Add breadcrumb for user action
    _flutterPush?.addBreadcrumb('Test button clicked', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    setState(() {
      _status = 'Button clicked at ${DateTime.now().toString().substring(11, 19)}';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Button works!')),
    );
  }

  Future<void> _testCrashReport() async {
    try {
      await _flutterPush?.reportCustomError(
        'Test crash report from example app',
        'TestError',
        'This is a test stack trace\n  at testCrashReport (main.dart:xxx)\n  at onPressed (main.dart:xxx)',
        {'test': true, 'timestamp': DateTime.now().toIso8601String()},
      );
      _showSuccessDialog('Test crash report sent!');
    } catch (error) {
      _showErrorDialog('Failed to send crash report: $error');
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('🚀 FlutterPush Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              'App Status',
              _status,
            ),
            const SizedBox(height: 15),
            _buildSection(
              'Current Version',
              _currentVersion,
              isVersion: true,
            ),
            const SizedBox(height: 15),
            _buildUpdateSection(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testButton,
              child: const Text('Test Button'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isChecking ? null : _checkForUpdates,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _testCrashReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Crash Report'),
            ),
            const SizedBox(height: 20),
            _buildInfoBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String label, String value, {bool isVersion = false}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isVersion ? 18 : 16,
              fontWeight: isVersion ? FontWeight.bold : FontWeight.w500,
              color: isVersion ? Colors.blue : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_isChecking)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (_isChecking) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _updateStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: Colors.blue, width: 4),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ℹ️ About FlutterPush',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'This app is integrated with FlutterPush for over-the-air updates.\n\n'
            '• Automatic update checking on app start\n'
            '• Manual update checking via button\n'
            '• Download and install updates seamlessly\n'
            '• Crash reporting and error tracking\n\n'
            'Make changes to the code and publish via CLI to see updates!',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

