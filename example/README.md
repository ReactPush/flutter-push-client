# FlutterPush Example App

Example Flutter app demonstrating how to integrate and use FlutterPush for over-the-air updates.

## Setup

1. Make sure you have Flutter installed:
```bash
flutter --version
```

2. Install dependencies:
```bash
cd example_flutter
flutter pub get
```

3. Update the API key in `lib/main.dart`:
```dart
const String apiKey = 'YOUR_APP_API_KEY';
```
Note: The API URL is automatically set to `http://localhost:8686` in debug mode and `https://reactpush.com` in release builds.

4. Run the app:
```bash
flutter run
```

## Features Demonstrated

- ✅ Automatic update checking on app start
- ✅ Manual update checking via button
- ✅ Download and install updates
- ✅ Crash reporting
- ✅ Error handling
- ✅ User-friendly UI with status updates

## Usage

1. Start the ReactPush API server (see main README)
2. Create an app and update via the API or CLI
3. Run this example app
4. The app will automatically check for updates on startup
5. Use the "Check for Updates" button to manually check
6. When an update is available, you'll be prompted to download and install it

## Testing Crash Reporting

Click the "Test Crash Report" button to send a test crash report to the server. This demonstrates the crash reporting functionality.

## License

MIT

