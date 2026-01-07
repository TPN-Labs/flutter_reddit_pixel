import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:reddit_pixel/src/domain/user_data.dart';

/// Normalizes and hashes user data for Reddit Conversions API.
///
/// This class implements Reddit's data normalization requirements:
/// - Email: trim whitespace, lowercase, then SHA-256 hash
/// - Phone: normalize to E.164 (strip non-digits), then SHA-256 hash
/// - IDFA (iOS): uppercase, then SHA-256 hash
/// - AAID (Android): lowercase, then SHA-256 hash
///
/// All hashing operations run in a separate isolate to avoid blocking
/// the main UI thread.
///
/// Example:
/// ```dart
/// final hashedEmail = await RedditNormalizer.normalizeAndHashEmail(
///   'User@Example.com',
/// );
/// // Returns SHA-256 hash of 'user@example.com'
/// ```
class RedditNormalizer {
  RedditNormalizer._();

  /// Normalizes and hashes an email address.
  ///
  /// Process:
  /// 1. Trim whitespace
  /// 2. Convert to lowercase
  /// 3. SHA-256 hash
  ///
  /// Returns `null` if the input is `null` or empty after trimming.
  static Future<String?> normalizeAndHashEmail(String? email) async {
    if (email == null || email.trim().isEmpty) return null;
    return Isolate.run(() => _hashEmail(email));
  }

  /// Normalizes and hashes a phone number.
  ///
  /// Process:
  /// 1. Remove all non-digit characters
  /// 2. SHA-256 hash
  ///
  /// The phone number should ideally be in E.164 format before calling
  /// this method (e.g., '+14155551234'), but any format will be normalized
  /// by stripping non-digits.
  ///
  /// Returns `null` if the input is `null` or contains no digits.
  static Future<String?> normalizeAndHashPhone(String? phone) async {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return Isolate.run(() => _sha256Hash(digits));
  }

  /// Normalizes and hashes an iOS IDFA.
  ///
  /// Process:
  /// 1. Convert to uppercase
  /// 2. SHA-256 hash
  ///
  /// Returns `null` if the input is `null` or empty.
  static Future<String?> normalizeAndHashIdfa(String? idfa) async {
    if (idfa == null || idfa.isEmpty) return null;
    return Isolate.run(() => _hashIdfa(idfa));
  }

  /// Normalizes and hashes an Android AAID.
  ///
  /// Process:
  /// 1. Convert to lowercase
  /// 2. SHA-256 hash
  ///
  /// Returns `null` if the input is `null` or empty.
  static Future<String?> normalizeAndHashAaid(String? aaid) async {
    if (aaid == null || aaid.isEmpty) return null;
    return Isolate.run(() => _hashAaid(aaid));
  }

  /// Normalizes all user data fields in a single isolate operation.
  ///
  /// This is more efficient than calling individual methods when you have
  /// multiple fields to normalize, as it runs all operations in a single
  /// isolate spawn.
  ///
  /// Returns a new [NormalizedUserData] with hashed PII fields and
  /// unchanged non-PII fields.
  static Future<NormalizedUserData> normalizeUserData(
    RedditUserData data,
  ) async {
    return Isolate.run(() => _normalizeUserDataSync(data));
  }

  // Synchronous implementations for isolate execution

  static String _hashEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return _sha256Hash(normalized);
  }

  static String _hashIdfa(String idfa) {
    final normalized = idfa.toUpperCase();
    return _sha256Hash(normalized);
  }

  static String _hashAaid(String aaid) {
    final normalized = aaid.toLowerCase();
    return _sha256Hash(normalized);
  }

  static String _sha256Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static NormalizedUserData _normalizeUserDataSync(RedditUserData data) {
    return NormalizedUserData(
      emailHash: data.email != null ? _hashEmail(data.email!) : null,
      externalIdHash:
          data.externalId != null ? _sha256Hash(data.externalId!) : null,
      uuid: data.uuid,
      idfaHash: data.idfa != null ? _hashIdfa(data.idfa!) : null,
      aaidHash: data.aaid != null ? _hashAaid(data.aaid!) : null,
      ipAddress: data.ipAddress,
      userAgent: data.userAgent,
      screenDimensions: data.screenDimensions,
      clickId: data.clickId,
    );
  }
}

/// User data with normalized and hashed PII fields.
///
/// This class represents user data ready to be sent to Reddit's API.
/// All PII fields have been normalized and SHA-256 hashed.
class NormalizedUserData {
  /// Creates normalized user data.
  const NormalizedUserData({
    this.emailHash,
    this.externalIdHash,
    this.uuid,
    this.idfaHash,
    this.aaidHash,
    this.ipAddress,
    this.userAgent,
    this.screenDimensions,
    this.clickId,
  });

  /// SHA-256 hash of the normalized email.
  final String? emailHash;

  /// SHA-256 hash of the external ID.
  final String? externalIdHash;

  /// UUID (not hashed).
  final String? uuid;

  /// SHA-256 hash of the normalized IDFA.
  final String? idfaHash;

  /// SHA-256 hash of the normalized AAID.
  final String? aaidHash;

  /// IP address (not hashed).
  final String? ipAddress;

  /// User agent string (not hashed).
  final String? userAgent;

  /// Screen dimensions (not hashed).
  final String? screenDimensions;

  /// Reddit click ID (not hashed).
  final String? clickId;

  /// Converts to JSON map for the Reddit API.
  Map<String, dynamic> toJson() {
    return {
      if (emailHash != null) 'em': emailHash,
      if (externalIdHash != null) 'external_id': externalIdHash,
      if (uuid != null) 'uuid': uuid,
      if (idfaHash != null) 'idfa': idfaHash,
      if (aaidHash != null) 'aaid': aaidHash,
      if (ipAddress != null) 'client_ip_address': ipAddress,
      if (userAgent != null) 'client_user_agent': userAgent,
      if (screenDimensions != null) 'screen_dimensions': screenDimensions,
      if (clickId != null) 'click_id': clickId,
    };
  }

  @override
  String toString() {
    return 'NormalizedUserData('
        'emailHash: ${_truncate(emailHash)}, '
        'externalIdHash: ${_truncate(externalIdHash)}, '
        'uuid: ${_truncate(uuid)}, '
        'idfaHash: ${_truncate(idfaHash)}, '
        'aaidHash: ${_truncate(aaidHash)}, '
        'ipAddress: [REDACTED], '
        'userAgent: ${_truncate(userAgent, 20)}, '
        'screenDimensions: $screenDimensions, '
        'clickId: [REDACTED])';
  }

  String? _truncate(String? value, [int maxLength = 8]) {
    if (value == null) return null;
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }
}
