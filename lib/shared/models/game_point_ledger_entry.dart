import 'package:cloud_firestore/cloud_firestore.dart';

class GamePointLedgerEntry {
  const GamePointLedgerEntry({
    required this.delta,
    required this.balanceAfter,
    required this.reason,
    this.meta,
    this.createdAt,
  });

  final int delta;
  final int balanceAfter;
  final String reason;
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;

  factory GamePointLedgerEntry.fromFirestore(Map<String, dynamic> data) {
    return GamePointLedgerEntry(
      delta: (data['delta'] as num?)?.toInt() ?? 0,
      balanceAfter: (data['balanceAfter'] as num?)?.toInt() ?? 0,
      reason: data['reason'] as String? ?? 'BONUS',
      meta: (data['meta'] as Map<String, dynamic>?) ??
          (data['meta'] is Map ? Map<String, dynamic>.from(data['meta'] as Map) : null),
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }
}
