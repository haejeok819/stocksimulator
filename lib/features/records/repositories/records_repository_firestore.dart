import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stocksimulator/features/records/models/attempt_record.dart';
import 'package:stocksimulator/features/records/repositories/records_repository.dart';

class RecordsRepositoryFirestore implements RecordsRepository {
  RecordsRepositoryFirestore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<AttemptRecord>> getRecords(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('records')
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data();
          return AttemptRecord.fromJson(<String, dynamic>{
            ...data,
            'id': (data['id'] as String?) ?? doc.id,
            'uid': uid,
            'createdAtIso':
                (data['createdAtIso'] as String?) ?? DateTime.now().toIso8601String(),
          });
        })
        .toList(growable: false);
  }

  @override
  Future<void> addRecord(AttemptRecord record) async {
    await _firestore
        .collection('users')
        .doc(record.uid)
        .collection('records')
        .doc(record.id)
        .set(<String, dynamic>{
      ...record.toJson(),
      'uid': record.uid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> clearRecords(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _firestore.collection('users').doc(uid).collection('records').get();

    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
