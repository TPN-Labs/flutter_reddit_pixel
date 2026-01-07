# Reddit Pixel Example

This example demonstrates how to use the `reddit_pixel` package to track conversion events with Reddit's Conversions API (CAPI) v3.

## Getting Started

1. Replace `YOUR_PIXEL_ID` in `lib/main.dart` with your actual Reddit Pixel ID
2. Replace the proxy URL with your backend endpoint (or use direct mode for testing)
3. Run the app

```bash
cd example
flutter pub get
flutter run
```

## Features Demonstrated

### Basic Usage

The example shows how to:

- Initialize the library with proxy mode (recommended)
- Track standard conversion events (Purchase, SignUp, Lead, etc.)
- Track custom events
- Manually flush the event queue

### Privacy Mode (Default)

By default, the library runs in privacy mode with no advertising ID tracking. This is shown in the example.

### Custom Identity Provider (Optional)

The example includes commented code showing how to implement a custom `RedditIdentityProvider` for IDFA/AAID tracking. To enable it:

1. Uncomment the `AppIdentityProvider` class at the bottom of `main.dart`
2. Add the required dependencies:
   ```yaml
   dependencies:
     advertising_id: ^2.3.0
     app_tracking_transparency: ^2.0.3
   ```
3. Uncomment the `identityProvider` parameter in `main()`

## Transport Modes

### Proxy Mode (Recommended)

```dart
await RedditPixel.initialize(
  pixelId: 'YOUR_PIXEL_ID',
  proxyUrl: 'https://your-server.com/api/reddit-events',
);
```

Your server should forward requests to Reddit's API with the authorization header.

### Direct Mode (Development Only)

```dart
await RedditPixel.initialize(
  pixelId: 'YOUR_PIXEL_ID',
  token: 'YOUR_REDDIT_API_TOKEN',
  testMode: true,
);
```

⚠️ **Warning:** Direct mode embeds your API token in the app binary. Use only for development.
