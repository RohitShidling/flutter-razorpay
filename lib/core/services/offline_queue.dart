import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
class DeadLetterItem {
  final String method;
  final String path;
  final Map<String, dynamic>? data;
  final String enqueuedAt;
  final String failedAt;
  final int statusCode;
  final String errorMessage;

  DeadLetterItem({
    required this.method,
    required this.path,
    this.data,
    required this.enqueuedAt,
    required this.failedAt,
    required this.statusCode,
    required this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'method': method,
        'path': path,
        if (data != null) 'data': data,
        'enqueuedAt': enqueuedAt,
        'failedAt': failedAt,
        'statusCode': statusCode,
        'errorMessage': errorMessage,
      };

  factory DeadLetterItem.fromJson(Map<String, dynamic> json) => DeadLetterItem(
        method: (json['method'] ?? '').toString(),
        path: (json['path'] ?? '').toString(),
        data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : null,
        enqueuedAt: (json['enqueuedAt'] ?? '').toString(),
        failedAt: (json['failedAt'] ?? '').toString(),
        statusCode: (json['statusCode'] as int?) ?? 0,
        errorMessage: (json['errorMessage'] ?? '').toString(),
      );
}

/// Exception thrown by the executor when a request fails with a known HTTP status code.
/// The offline queue uses this to distinguish permanent (4xx) vs transient (5xx/network) errors.
class OfflineRequestException implements Exception {
  final int statusCode;
  final String message;

  OfflineRequestException({required this.statusCode, required this.message});

  /// True when the error is permanent (client-side bad request — re-queuing won't help).
  bool get isPermanent => statusCode >= 400 && statusCode < 500;

  @override
  String toString() => 'OfflineRequestException($statusCode): $message';
}

class OfflineQueue {
  OfflineQueue._();

  static const _queueKey = 'offline:queue:v1';
  static const _deadLetterKey = 'offline:dead_letter:v1';
  static const _secureStorage = FlutterSecureStorage();

  /// Maximum retry count per item before it is moved to the dead-letter store.
  static const int maxRetries = 3;

  static Future<List<Map<String, dynamic>>> _load() async {
    final raw = await _secureStorage.read(key: _queueKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Future<void> _save(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) {
      await _secureStorage.delete(key: _queueKey);
    } else {
      await _secureStorage.write(key: _queueKey, value: jsonEncode(items));
    }
  }

  // ── Dead-letter store ──────────────────────────────────────────────────────

  static Future<List<DeadLetterItem>> loadDeadLetters() async {
    final raw = await _secureStorage.read(key: _deadLetterKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => DeadLetterItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _addToDeadLetter(Map<String, dynamic> item, int statusCode, String errorMessage) async {
    final raw = await _secureStorage.read(key: _deadLetterKey);
    List<dynamic> existing = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) existing = decoded;
      } catch (_) {}
    }
    existing.add(DeadLetterItem(
      method: (item['method'] ?? '').toString(),
      path: (item['path'] ?? '').toString(),
      data: item['data'] is Map ? Map<String, dynamic>.from(item['data'] as Map) : null,
      enqueuedAt: (item['enqueuedAt'] ?? '').toString(),
      failedAt: DateTime.now().toIso8601String(),
      statusCode: statusCode,
      errorMessage: errorMessage,
    ).toJson());
    await _secureStorage.write(key: _deadLetterKey, value: jsonEncode(existing));
  }

  /// Clear all dead-letter items (e.g. after user acknowledges them).
  static Future<void> clearDeadLetters() async {
    await _secureStorage.delete(key: _deadLetterKey);
  }

  static Future<int> deadLetterCount() async {
    final items = await loadDeadLetters();
    return items.length;
  }

  static Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? data,
  }) async {
    final items = await _load();
    items.add(<String, dynamic>{
      'method': method.toUpperCase(),
      'path': path,
      if (data != null) 'data': data,
      'enqueuedAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
    await _save(items);
  }

  static Future<int> pendingCount() async {
    final items = await _load();
    return items.length;
  }

  /// Process queued requests. Distinguishes permanent vs transient failures:
  ///
  /// - **4xx (permanent)**: Item is removed from queue and placed in the dead-letter
  ///   store. Processing continues with the next item (no head-of-line blocking).
  ///
  /// - **5xx / network error (transient)**: Item's retry counter is incremented and
  ///   it is re-queued. If retryCount reaches [maxRetries], it is moved to dead-letter.
  ///   Processing stops at the first transient error (preserve order).
  ///
  /// The executor should throw [OfflineRequestException] with the HTTP status code on
  /// API errors, or any other exception for network/transport failures.
  ///
  /// Returns the number of successfully processed items.
  static Future<OfflineQueueResult> process({
    required Future<dynamic> Function(String method, String path, Map<String, dynamic>? data) executor,
  }) async {
    final items = await _load();
    var processed = 0;
    var deadLettered = 0;
    final remaining = List<Map<String, dynamic>>.from(items);

    for (final item in items) {
      final method = (item['method'] ?? '').toString().toUpperCase();
      final path = (item['path'] ?? '').toString();
      final dataRaw = item['data'];
      final data = dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : null;
      final retryCount = (item['retryCount'] as int?) ?? 0;

      if (method.isEmpty || path.isEmpty) {
        // Drop corrupt entries silently.
        remaining.remove(item);
        await _save(remaining);
        processed += 1;
        continue;
      }

      try {
        await executor(method, path, data);
        remaining.remove(item);
        await _save(remaining);
        processed += 1;
      } on OfflineRequestException catch (e) {
        if (e.isPermanent || retryCount >= maxRetries) {
          // Permanent 4xx OR exhausted retries → dead-letter; do NOT re-queue.
          // Processing continues to allow later items to succeed (no head-of-line block).
          await _addToDeadLetter(item, e.statusCode, e.message);
          remaining.remove(item);
          await _save(remaining);
          deadLettered += 1;
        } else {
          // Transient 5xx — increment retry count, re-queue, stop processing (order preserved).
          final idx = remaining.indexOf(item);
          if (idx != -1) {
            remaining[idx] = {...item, 'retryCount': retryCount + 1};
          }
          await _save(remaining);
          break;
        }
      } catch (e) {
        // Unknown / network error — treat as transient.
        if (retryCount >= maxRetries) {
          await _addToDeadLetter(item, 0, e.toString());
          remaining.remove(item);
          await _save(remaining);
          deadLettered += 1;
        } else {
          final idx = remaining.indexOf(item);
          if (idx != -1) {
            remaining[idx] = {...item, 'retryCount': retryCount + 1};
          }
          await _save(remaining);
          break;
        }
      }
    }

    return OfflineQueueResult(processed: processed, deadLettered: deadLettered);
  }
}

class OfflineQueueResult {
  final int processed;
  final int deadLettered;

  const OfflineQueueResult({required this.processed, required this.deadLettered});
}
