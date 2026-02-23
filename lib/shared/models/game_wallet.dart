import 'package:cloud_firestore/cloud_firestore.dart';

class GameWallet {
  const GameWallet({
    required this.uid,
    required this.gamePoints,
    this.lastCheckInDate,
    this.streak,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final int gamePoints;
  final String? lastCheckInDate;
  final int? streak;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory GameWallet.fromFirestore(String uid, Map<String, dynamic> data) {
    return GameWallet(
      uid: uid,
      gamePoints: (data['gamePoints'] as num?)?.toInt() ?? 0,
      lastCheckInDate: data['lastCheckInDate'] as String?,
      streak: (data['streak'] as num?)?.toInt(),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
