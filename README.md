# reddit_pixel

[![Pub Version](https://img.shields.io/pub/v/reddit_pixel.svg)](https://pub.dev/packages/reddit_pixel)
[![Build Status](https://github.com/TPN-Labs/flutter_reddit_pixel/actions/workflows/code-quality.yml/badge.svg)](https://github.com/TPN-Labs/flutter_reddit_pixel/actions/workflows/code-quality.yml)
[![Style: Very Good Analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![Codecov](https://codecov.io/gh/TPN-Labs/flutter_reddit_pixel/graph/badge.svg)](https://codecov.io/gh/TPN-Labs/flutter_reddit_pixel)
[![License: BSD-3](https://img.shields.io/badge/license-BSD--3-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

A privacy-centric, backend-agnostic Flutter library for Reddit Conversions API (CAPI) v3. Track conversion events with offline-first persistence, automatic retry, and PII hashing.

## Features

- **Privacy-First**: No tracking dependencies by default. IDFA/AAID support requires explicit opt-in
- **Backend-Agnostic**: Use proxy mode (recommended) or direct mode for development
- **Offline-First**: Events are queued locally with Hive and sent when online
- **Performance**: PII normalization and SHA-256 hashing run in isolates
- **Automatic Retry**: Exponential backoff for failed requests
- **All Event Types**: Purchase, SignUp, Lead, AddToCart, AddToWishlist, Search, ViewContent, PageVisit, and Custom events

See the [example](example/README.md) for runnable examples of various usages.

## Platform Support

| Android | iOS | macOS | Web | Linux | Windows |
|:-------:|:---:|:-----:|:---:|:-----:|:-------:|
|    ✅   |  ✅ |   ✅  |  ✅ |   ✅  |    ✅   |

### Features Supported

| Feature | Android | iOS | macOS | Web | Linux | Windows |
|---------|:-------:|:---:|:-----:|:---:|:-----:|:-------:|
| Proxy Transport | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Direct Transport | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Offline Queue | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| IDFA/AAID Support | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  reddit_pixel: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Configuration

### Proxy Server Setup (Recommended)

For production, use a proxy server to keep your Reddit API token secure. Your server should:

1. Receive the event payload from this library
2. Add the Reddit API authorization header
3. Forward the request to Reddit's Conversions API
4. Return the response

**Example proxy endpoint (Node.js/Express):**

```javascript
app.post('/api/reddit-events/:pixelId', async (req, res) => {
  const response = await fetch(
    `https://ads-api.reddit.com/api/v3/pixels/${req.params.pixelId}/conversion_events`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.REDDIT_API_TOKEN}`,
      },
      body: JSON.stringify(req.body),
    }
  );
  res.status(response.status).json(await response.json());
});
```

### iOS Configuration

If you plan to use IDFA tracking, add to your `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to measure advertising effectiveness.</string>
```

### Android Configuration

No special configuration required. For AAID tracking, Google Play Services must be available on the device.

## Usage

### Basic Usage

```dart
import 'package:reddit_pixel/reddit_pixel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize with proxy mode (recommended)
  await RedditPixel.initialize(
    pixelId: 'your-pixel-id',
    proxyUrl: 'https://your-server.com/api/reddit-events',
  );

  runApp(MyApp());
}

// Track a purchase anywhere in your app
await RedditPixel.instance.trackPurchase(
  value: 99.99,
  currency: 'USD',
  itemCount: 2,
  userData: RedditUserData(
    email: 'customer@example.com',
    externalId: 'user-123',
  ),
);
```

### Advanced Usage

#### Direct Mode (Development Only)

⚠️ **Warning:** Direct mode embeds your Reddit API token in the app binary. Use only for development.

```dart
await RedditPixel.initialize(
  pixelId: 'your-pixel-id',
  token: 'your-reddit-api-token',
  testMode: true,  // Events won't affect production data
  debug: true,     // Enable debug logging
);
```

#### Custom Identity Provider

To enable IDFA/AAID tracking, implement `RedditIdentityProvider`:

```dart
import 'package:advertising_id/advertising_id.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class AppIdentityProvider implements RedditIdentityProvider {
  @override
  Future<String?> getAdvertisingId() async {
    try {
      if (Platform.isIOS) {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status != TrackingStatus.authorized) return null;
      }
      return await AdvertisingId.id(true);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isTrackingEnabled() async {
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      return status == TrackingStatus.authorized;
    }
    return true;
  }
}

// Use it during initialization
await RedditPixel.initialize(
  pixelId: 'your-pixel-id',
  proxyUrl: 'https://your-server.com/api/reddit-events',
  identityProvider: AppIdentityProvider(),
);
```

#### All Event Types

```dart
// Standard events
await RedditPixel.instance.trackPurchase(value: 99.99, currency: 'USD');
await RedditPixel.instance.trackSignUp();
await RedditPixel.instance.trackLead();
await RedditPixel.instance.trackAddToCart(value: 49.99, currency: 'USD');
await RedditPixel.instance.trackAddToWishlist(value: 199.99, currency: 'USD');
await RedditPixel.instance.trackSearch(searchString: 'wireless headphones');
await RedditPixel.instance.trackViewContent(contentId: 'product-123');
await RedditPixel.instance.trackPageVisit(pageUrl: '/checkout');

// Custom events
await RedditPixel.instance.trackCustom(
  'VideoWatched',
  customData: {'video_id': 'vid-123', 'duration': 120},
);

// Generic tracking with event objects
await RedditPixel.instance.track(
  PurchaseEvent(
    value: 99.99,
    currency: 'USD',
    userData: RedditUserData(email: 'user@example.com'),
  ),
);
```

#### Queue Management

```dart
// Get pending event count
final count = await RedditPixel.instance.pendingEventCount;

// Force immediate flush of queued events
await RedditPixel.instance.flush();

// Dispose when done (e.g., app termination)
await RedditPixel.instance.dispose();
```

## API Reference

### RedditPixel

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize the library with configuration |
| `track(event)` | Track any `RedditEvent` |
| `trackPurchase()` | Track a purchase conversion |
| `trackSignUp()` | Track a sign-up conversion |
| `trackLead()` | Track a lead generation |
| `trackAddToCart()` | Track add-to-cart action |
| `trackAddToWishlist()` | Track add-to-wishlist action |
| `trackSearch()` | Track a search action |
| `trackViewContent()` | Track content view |
| `trackPageVisit()` | Track page/screen visit |
| `trackCustom()` | Track custom events |
| `flush()` | Force send queued events |
| `dispose()` | Release resources |

### RedditUserData

| Field | Type | Description |
|-------|------|-------------|
| `email` | `String?` | User's email (hashed before sending) |
| `externalId` | `String?` | Your system's user ID (hashed) |
| `uuid` | `String?` | UUID for cross-device attribution |
| `idfa` | `String?` | iOS advertising ID (hashed) |
| `aaid` | `String?` | Android advertising ID (hashed) |
| `ipAddress` | `String?` | User's IP address |
| `userAgent` | `String?` | Browser/app user agent |
| `clickId` | `String?` | Reddit click ID (`rdt_cid` parameter) |

## Security

### PII Handling

All personally identifiable information (PII) is automatically normalized and SHA-256 hashed before transmission:

- **Email**: Trimmed, lowercased, then hashed
- **Phone**: Normalized to digits only, then hashed
- **IDFA**: Uppercased, then hashed
- **AAID**: Lowercased, then hashed

### Transport Security

| Mode | Token Location | Recommendation |
|------|----------------|----------------|
| **Proxy** | Server-side only | ✅ Production |
| **Direct** | Embedded in app | ⚠️ Development only |

## Issues

Please file issues, bugs, or feature requests in our [issue tracker](https://github.com/TPN-Labs/flutter_reddit_pixel/issues/new).

## Contributing

If you wish to contribute, please review our contribution guidelines and open a [pull request](https://github.com/TPN-Labs/flutter_reddit_pixel/pulls).

## License

This project is licensed under the BSD-3-Clause License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/TPN-Labs">TPN Labs</a>
</p>
