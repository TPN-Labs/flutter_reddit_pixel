/// Container for user data used in Reddit conversion events.
///
/// This class holds personally identifiable information (PII) that will be
/// normalized and hashed before being sent to Reddit's Conversions API.
///
/// All fields are optional. Include as much user data as available to improve
/// attribution accuracy.
///
/// **Privacy Note:** The [toString] method redacts sensitive information
/// for safe logging. Raw PII is never logged.
///
/// Example:
/// ```dart
/// final userData = RedditUserData(
///   email: 'user@example.com',
///   externalId: 'user-123',
/// );
/// ```
class RedditUserData {
  /// Creates a new [RedditUserData] instance.
  const RedditUserData({
    this.email,
    this.externalId,
    this.uuid,
    this.idfa,
    this.aaid,
    this.ipAddress,
    this.userAgent,
    this.screenDimensions,
    this.clickId,
  });

  /// User's email address.
  ///
  /// Will be normalized (trimmed, lowercased) and SHA-256 hashed before
  /// sending to Reddit.
  final String? email;

  /// External user identifier from your system.
  ///
  /// Will be SHA-256 hashed before sending to Reddit.
  final String? externalId;

  /// UUID v4 for the user.
  ///
  /// Used for cross-device attribution.
  final String? uuid;

  /// iOS Identifier for Advertisers (IDFA).
  ///
  /// Will be uppercased and SHA-256 hashed before sending to Reddit.
  /// Requires App Tracking Transparency permission on iOS 14.5+.
  final String? idfa;

  /// Android Advertising ID (AAID).
  ///
  /// Will be lowercased and SHA-256 hashed before sending to Reddit.
  final String? aaid;

  /// User's IP address.
  ///
  /// Used for geo-targeting and fraud detection.
  final String? ipAddress;

  /// User's browser/app user agent string.
  final String? userAgent;

  /// Screen dimensions in format "WIDTHxHEIGHT" (e.g., "1920x1080").
  final String? screenDimensions;

  /// Reddit click ID from ad click URL parameter.
  ///
  /// This is the `rdt_cid` parameter from Reddit ad clicks.
  final String? clickId;

  /// Creates a copy of this [RedditUserData] with the given fields replaced.
  RedditUserData copyWith({
    String? email,
    String? externalId,
    String? uuid,
    String? idfa,
    String? aaid,
    String? ipAddress,
    String? userAgent,
    String? screenDimensions,
    String? clickId,
  }) {
    return RedditUserData(
      email: email ?? this.email,
      externalId: externalId ?? this.externalId,
      uuid: uuid ?? this.uuid,
      idfa: idfa ?? this.idfa,
      aaid: aaid ?? this.aaid,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      screenDimensions: screenDimensions ?? this.screenDimensions,
      clickId: clickId ?? this.clickId,
    );
  }

  /// Converts this user data to a JSON map.
  ///
  /// **Note:** This returns raw values. Use [RedditNormalizer] to get
  /// normalized and hashed values for the API.
  Map<String, dynamic> toJson() {
    return {
      if (email != null) 'email': email,
      if (externalId != null) 'external_id': externalId,
      if (uuid != null) 'uuid': uuid,
      if (idfa != null) 'idfa': idfa,
      if (aaid != null) 'aaid': aaid,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (userAgent != null) 'user_agent': userAgent,
      if (screenDimensions != null) 'screen_dimensions': screenDimensions,
      if (clickId != null) 'click_id': clickId,
    };
  }

  /// Creates a [RedditUserData] from a JSON map.
  factory RedditUserData.fromJson(Map<String, dynamic> json) {
    return RedditUserData(
      email: json['email'] as String?,
      externalId: json['external_id'] as String?,
      uuid: json['uuid'] as String?,
      idfa: json['idfa'] as String?,
      aaid: json['aaid'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      screenDimensions: json['screen_dimensions'] as String?,
      clickId: json['click_id'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RedditUserData &&
        other.email == email &&
        other.externalId == externalId &&
        other.uuid == uuid &&
        other.idfa == idfa &&
        other.aaid == aaid &&
        other.ipAddress == ipAddress &&
        other.userAgent == userAgent &&
        other.screenDimensions == screenDimensions &&
        other.clickId == clickId;
  }

  @override
  int get hashCode {
    return Object.hash(
      email,
      externalId,
      uuid,
      idfa,
      aaid,
      ipAddress,
      userAgent,
      screenDimensions,
      clickId,
    );
  }

  /// Returns a redacted string representation for safe logging.
  ///
  /// Sensitive fields (email, externalId, idfa, aaid, ipAddress) are
  /// replaced with `[REDACTED]` to prevent PII leakage in logs.
  @override
  String toString() {
    final buffer = StringBuffer('RedditUserData(');
    final parts = <String>[];

    if (email != null) parts.add('email: [REDACTED]');
    if (externalId != null) parts.add('externalId: [REDACTED]');
    if (uuid != null) parts.add('uuid: [REDACTED]');
    if (idfa != null) parts.add('idfa: [REDACTED]');
    if (aaid != null) parts.add('aaid: [REDACTED]');
    if (ipAddress != null) parts.add('ipAddress: [REDACTED]');
    if (userAgent != null) parts.add('userAgent: ${_truncate(userAgent!, 20)}');
    if (screenDimensions != null) {
      parts.add('screenDimensions: $screenDimensions');
    }
    if (clickId != null) parts.add('clickId: [REDACTED]');

    buffer
      ..write(parts.join(', '))
      ..write(')');
    return buffer.toString();
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }
}
