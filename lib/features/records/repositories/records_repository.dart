import 'package:stocksimulator/features/records/models/attempt_record.dart';

abstract class RecordsRepository {
  Future<List<AttemptRecord>> getRecords(String uid);
  Future<void> addRecord(AttemptRecord record);
  Future<void> clearRecords(String uid);
}
