import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/features/records/models/attempt_record.dart';
import 'package:stocksimulator/features/records/repositories/records_repository.dart';
import 'package:stocksimulator/features/records/repositories/records_repository_firestore.dart';
import 'package:stocksimulator/features/records/repositories/records_repository_local.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/services/firebase_runtime.dart';

final Provider<RecordsRepository> recordsRepositoryProvider =
    Provider<RecordsRepository>((Ref ref) {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || !FirebaseRuntime.isReady) {
    return RecordsRepositoryLocal();
  }

  if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
    return RecordsRepositoryFirestore();
  }

  return RecordsRepositoryLocal();
});

final FutureProvider<List<AttemptRecord>> recordsListProvider =
    FutureProvider<List<AttemptRecord>>((Ref ref) async {
  final String? uid = ref.watch(authControllerProvider).user?.uid;
  if (uid == null || uid.isEmpty) {
    return <AttemptRecord>[];
  }
  return ref.watch(recordsRepositoryProvider).getRecords(uid);
});

final Provider<RecordsController> recordsControllerProvider =
    Provider<RecordsController>((Ref ref) {
  return RecordsController(ref: ref);
});

class RecordsController {
  RecordsController({required this.ref});

  final Ref ref;

  Future<void> addRecord(AttemptRecord record) async {
    await ref.read(recordsRepositoryProvider).addRecord(record);
    ref.invalidate(recordsListProvider);
  }

  Future<void> clearCurrentUserRecords() async {
    final String? uid = ref.read(authControllerProvider).user?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    await ref.read(recordsRepositoryProvider).clearRecords(uid);
    ref.invalidate(recordsListProvider);
  }
}
