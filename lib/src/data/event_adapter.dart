import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:reddit_pixel/src/domain/event.dart';
import 'package:reddit_pixel/src/domain/user_data.dart';

/// Hive TypeAdapter for [RedditEvent] serialization.
///
/// This adapter handles serialization of all [RedditEvent] subclasses
/// using JSON encoding for maximum flexibility and forward compatibility.
class RedditEventAdapter extends TypeAdapter<RedditEvent> {
  @override
  final int typeId = 0;

  @override
  RedditEvent read(BinaryReader reader) {
    final jsonString = reader.readString();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return RedditEvent.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, RedditEvent obj) {
    final json = obj.toJson();
    writer.writeString(jsonEncode(json));
  }
}

/// Hive TypeAdapter for [RedditUserData] serialization.
class RedditUserDataAdapter extends TypeAdapter<RedditUserData> {
  @override
  final int typeId = 1;

  @override
  RedditUserData read(BinaryReader reader) {
    final jsonString = reader.readString();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return RedditUserData.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, RedditUserData obj) {
    writer.writeString(jsonEncode(obj.toJson()));
  }
}

/// Wrapper model for storing events with metadata in Hive.
///
/// This model wraps a [RedditEvent] with additional metadata needed
/// for queue management, such as the event ID for deduplication.
class StoredEvent {
  /// Creates a stored event.
  StoredEvent({
    required this.eventId,
    required this.eventJson,
    required this.createdAt,
  });

  /// The unique event ID (matches [RedditEvent.eventId]).
  final String eventId;

  /// The serialized event JSON.
  final String eventJson;

  /// When this event was stored in the queue.
  final DateTime createdAt;

  /// Creates a [StoredEvent] from a [RedditEvent].
  factory StoredEvent.fromEvent(RedditEvent event) {
    return StoredEvent(
      eventId: event.eventId,
      eventJson: jsonEncode(event.toJson()),
      createdAt: DateTime.now(),
    );
  }

  /// Deserializes the stored event back to a [RedditEvent].
  RedditEvent toEvent() {
    final json = jsonDecode(eventJson) as Map<String, dynamic>;
    return RedditEvent.fromJson(json);
  }

  /// Converts to a map for Hive storage.
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventJson': eventJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Creates from a Hive storage map.
  factory StoredEvent.fromMap(Map<dynamic, dynamic> map) {
    return StoredEvent(
      eventId: map['eventId'] as String,
      eventJson: map['eventJson'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

/// Hive TypeAdapter for [StoredEvent] serialization.
class StoredEventAdapter extends TypeAdapter<StoredEvent> {
  @override
  final int typeId = 2;

  @override
  StoredEvent read(BinaryReader reader) {
    final map = reader.readMap();
    return StoredEvent.fromMap(map);
  }

  @override
  void write(BinaryWriter writer, StoredEvent obj) {
    writer.writeMap(obj.toMap());
  }
}
