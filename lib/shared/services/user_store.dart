import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserStore {
  const UserStore({FirebaseFirestore? firestore})
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
}
