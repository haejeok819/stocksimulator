import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stocksimulator/features/records/models/attempt_record.dart';
import 'package:stocksimulator/features/records/repositories/records_repository.dart';

class RecordsRepositoryLocal implements RecordsRepository {
  @override
  Future<List<AttemptRecord>> getRecords(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) {
      return <AttemptRecord>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final List<AttemptRecord> records = list
          .whereType<Map>()
          .map((Map row) => AttemptRecord.fromJson(row.cast<String, dynamic>()))
          .toList(growable: false);
      records.sort((AttemptRecord a, AttemptRecord b) => b.createdAtIso.compareTo(a.createdAtIso));
      return records;
    } on FormatException {
      return <AttemptRecord>[];
    }
  }

  @override
  Future<void> addRecord(AttemptRecord record) async {
    final List<AttemptRecord> existing = await getRecords(record.uid);
    final List<AttemptRecord> merged = <AttemptRecord>[record, ...existing]
        .fold<List<AttemptRecord>>(<AttemptRecord>[], (List<AttemptRecord> acc, AttemptRecord item) {
      final bool exists = acc.any((AttemptRecord e) => e.id == item.id);
      if (!exists) {
        acc.add(item);
      }
      return acc;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(record.uid),
      jsonEncode(merged.map((AttemptRecord e) => e.toJson()).toList(growable: false)),
    );
  }

  @override
  Future<void> clearRecords(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }

  String _key(String uid) => 'records_$uid';
}
