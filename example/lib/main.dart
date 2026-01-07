import 'package:flutter/material.dart';
import 'package:reddit_pixel/reddit_pixel.dart';

/// Example app demonstrating the reddit_pixel package.
///
/// This example shows:
/// 1. Initializing the library in privacy mode (no tracking)
/// 2. Tracking various conversion events
/// 3. How to implement a custom identity provider (commented)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RedditPixel with proxy mode (recommended for production)
  // Replace with your actual pixel ID and proxy URL
  await RedditPixel.initialize(
    pixelId: 'YOUR_PIXEL_ID',
    proxyUrl: 'https://your-server.com/api/reddit-events',
    testMode: true, // Enable test mode during development
    debug: true, // Enable debug logging
    // identityProvider: AppIdentityProvider(), // Uncomment to enable IDFA/AAID
  );

  runApp(const RedditPixelExampleApp());
}

/// Main application widget.
class RedditPixelExampleApp extends StatelessWidget {
  const RedditPixelExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reddit Pixel Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const ExampleHomePage(),
    );
  }
}

/// Home page with buttons to trigger different events.
class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  String _status = 'Ready to track events';
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _updatePendingCount();
  }

  Future<void> _updatePendingCount() async {
    final count = await RedditPixel.instance.pendingEventCount;
    setState(() {
      _pendingCount = count;
    });
  }

  Future<void> _trackEvent(String eventName, Future<void> Function() track) async {
    setState(() {
      _status = 'Tracking $eventName...';
    });

    try {
      await track();
      setState(() {
        _status = '$eventName tracked successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error tracking $eventName: $e';
      });
    }

    await _updatePendingCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Reddit Pixel Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 8),
                    Text('Pending events: $_pendingCount'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Event tracking buttons
            Text(
              'Standard Events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            _EventButton(
              label: 'Track Purchase',
              icon: Icons.shopping_cart,
              onPressed: () => _trackEvent(
                'Purchase',
                () => RedditPixel.instance.trackPurchase(
                  value: 99.99,
                  currency: 'USD',
                  itemCount: 2,
                  userData: RedditUserData(
                    email: 'customer@example.com',
                    externalId: 'user-123',
                  ),
                ),
              ),
            ),

            _EventButton(
              label: 'Track Sign Up',
              icon: Icons.person_add,
              onPressed: () => _trackEvent(
                'SignUp',
                () => RedditPixel.instance.trackSignUp(
                  userData: RedditUserData(
                    email: 'newuser@example.com',
                  ),
                ),
              ),
            ),

            _EventButton(
              label: 'Track Lead',
              icon: Icons.contact_mail,
              onPressed: () => _trackEvent(
                'Lead',
                () => RedditPixel.instance.trackLead(
                  userData: RedditUserData(
                    email: 'lead@example.com',
                  ),
                  customData: {'lead_source': 'contact_form'},
                ),
              ),
            ),

            _EventButton(
              label: 'Track Add to Cart',
              icon: Icons.add_shopping_cart,
              onPressed: () => _trackEvent(
                'AddToCart',
                () => RedditPixel.instance.trackAddToCart(
                  value: 49.99,
                  currency: 'USD',
                  itemCount: 1,
                ),
              ),
            ),

            _EventButton(
              label: 'Track Add to Wishlist',
              icon: Icons.favorite,
              onPressed: () => _trackEvent(
                'AddToWishlist',
                () => RedditPixel.instance.trackAddToWishlist(
                  value: 199.99,
                  currency: 'USD',
                ),
              ),
            ),

            _EventButton(
              label: 'Track Search',
              icon: Icons.search,
              onPressed: () => _trackEvent(
                'Search',
                () => RedditPixel.instance.trackSearch(
                  searchString: 'wireless headphones',
                ),
              ),
            ),

            _EventButton(
              label: 'Track View Content',
              icon: Icons.visibility,
              onPressed: () => _trackEvent(
                'ViewContent',
                () => RedditPixel.instance.trackViewContent(
                  contentId: 'product-456',
                  contentName: 'Premium Headphones',
                ),
              ),
            ),

            _EventButton(
              label: 'Track Page Visit',
              icon: Icons.web,
              onPressed: () => _trackEvent(
                'PageVisit',
                () => RedditPixel.instance.trackPageVisit(
                  pageUrl: '/checkout',
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Custom Events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            _EventButton(
              label: 'Track Custom Event',
              icon: Icons.code,
              onPressed: () => _trackEvent(
                'Custom',
                () => RedditPixel.instance.trackCustom(
                  'VideoWatched',
                  customData: {
                    'video_id': 'vid-789',
                    'duration_seconds': 120,
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Queue Management',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            _EventButton(
              label: 'Flush Queue',
              icon: Icons.sync,
              onPressed: () async {
                setState(() {
                  _status = 'Flushing queue...';
                });
                await RedditPixel.instance.flush();
                await _updatePendingCount();
                setState(() {
                  _status = 'Queue flushed!';
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EventButton extends StatelessWidget {
  const _EventButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

// =============================================================================
// OPTIONAL: Custom Identity Provider Implementation
// =============================================================================
// Uncomment the code below to enable IDFA/AAID tracking.
// You'll need to add these dependencies to your pubspec.yaml:
//   - advertising_id: ^2.3.0
//   - app_tracking_transparency: ^2.0.3
//
// Then uncomment the identityProvider parameter in main().
// =============================================================================

/*
import 'package:advertising_id/advertising_id.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'dart:io' show Platform;

/// Custom identity provider that retrieves IDFA/AAID.
///
/// This implementation:
/// 1. Checks App Tracking Transparency status on iOS
/// 2. Retrieves the appropriate advertising ID for the platform
class AppIdentityProvider implements RedditIdentityProvider {
  @override
  Future<String?> getAdvertisingId() async {
    try {
      // On iOS, first check ATT status
      if (Platform.isIOS) {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status != TrackingStatus.authorized) {
          return null;
        }
      }

      // Get the advertising ID
      return await AdvertisingId.id(true);
    } catch (e) {
      // Failed to get ID - return null
      return null;
    }
  }

  @override
  Future<bool> isTrackingEnabled() async {
    try {
      if (Platform.isIOS) {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        return status == TrackingStatus.authorized;
      }

      // On Android, check if the ID is available
      final id = await AdvertisingId.id(true);
      return id != null && id.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
*/
