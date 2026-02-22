import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserStore {
  UserStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> upsertGoogleUser(User user) async {
    final DocumentReference<Map<String, dynamic>> doc =
        _firestore.collection('users').doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> snap = await doc.get();

    final Map<String, dynamic> data = <String, dynamic>{
      'uid': user.uid,
      'provider': 'google',
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'lastSignInAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await doc.set(data, SetOptions(merge: true));
  }

  Future<bool?> getAdsRemoved(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _firestore.collection('users').doc(uid).get();
    if (!snap.exists) {
      return null;
    }

    final Map<String, dynamic>? data = snap.data();
    final Object? value = data?['adsRemoved'];
    if (value is bool) {
      return value;
    }
    return null;
  }

  Future<void> setAdsRemoved({required String uid, required bool adsRemoved}) async {
    await _firestore.collection('users').doc(uid).set(<String, dynamic>{
      'adsRemoved': adsRemoved,
      if (adsRemoved) 'adsRemovedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
