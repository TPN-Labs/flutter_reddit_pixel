## 1.0.0

*   **Initial Release**: introduced a privacy-centric, backend-agnostic library for Reddit Conversions API (CAPI) v3.
*   **Event Tracking**: Added support for standard events (`Purchase`, `SignUp`, `Lead`, `AddToCart`, `AddToWishlist`, `Search`, `ViewContent`, `PageVisit`) and custom events.
*   **Transport Modes**: Implemented dual transport modes:
    *   **Direct Mode**: Send events directly to Reddit API using an access token.
    *   **Proxy Mode**: Securely route events through a proxy server to keep tokens hidden.
*   **Offline First**: Integrated `Hive` for persistent local queuing of events when offline, with automatic retry and background flushing.
*   **User Data Enrichment**: Added automatic enrichment of events with device identifiers (IDFA/AAID) via `RedditIdentityProvider`.
*   **Developer Experience**: Included robust debug logging, configurable flush intervals, and a dedicated test mode.
