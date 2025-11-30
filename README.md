# FlutterPush Client

Flutter client library for ReactPush update system. This library allows Flutter apps to check for and download remote bundle updates.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_push_client:
    path: ../client_flutter
```

Or if published to pub.dev:

```yaml
dependencies:
  flutter_push_client: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Setup

```dart
import 'package:flutter_push_client/flutter_push.dart';

final flutterPush = FlutterPush(
  apiKey: 'YOUR_APP_API_KEY',
  apiUrl: 'https://your-api-url.com',
  appVersion: '1.0.0', // Required: Your app version
  userId: 'optional-user-id', // Optional
  onUpdateAvailable: (update) {
    print('Update available: ${update['version']}');
  },
  onUpdateDownloaded: (update) {
    print('Update downloaded: ${update['version']}');
  },
  onError: (error) {
    print('FlutterPush error: $error');
  },
);

// Check for updates
await flutterPush.checkForUpdate();

// Or sync automatically
await flutterPush.sync(
  checkFrequency: 'ON_APP_START',
  installMode: 'ON_NEXT_RESTART',
);
```

### API

#### `checkForUpdate()`
Checks for available updates from the server.

#### `downloadUpdate(update)`
Downloads the update bundle and assets.

#### `sync(options)`
Automatically checks for updates and downloads them based on the provided options.

Options:
- `checkFrequency`: 'ON_APP_START' | 'ON_APP_RESUME' | 'MANUAL'
- `installMode`: 'IMMEDIATE' | 'ON_NEXT_RESTART' | 'ON_NEXT_RESUME'

#### `getDownloadedBundleURL()`
Returns the local file path of the downloaded bundle, or `null` if no bundle is downloaded. This can be used by native code to load the bundle.

```dart
final bundlePath = await flutterPush.getDownloadedBundleURL();
if (bundlePath != null) {
  print('Downloaded bundle path: $bundlePath');
}
```

#### `getBundleManager()`
Returns the bundle manager instance for advanced usage.

## Crash Reporting

FlutterPush includes built-in crash reporting:

```dart
// Report a JavaScript error
await flutterPush.reportJavaScriptError(error, {
  'context': 'myFeature',
});

// Report a custom error
await flutterPush.reportCustomError(
  'Something went wrong',
  'CustomError',
  stackTrace,
  {'userId': '123'},
);

// Add breadcrumbs
flutterPush.addBreadcrumb('User clicked button', {
  'buttonId': 'submit',
});
```

## License

MIT

