import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stocksimulator/shared/models/game_point_ledger_entry.dart';
import 'package:stocksimulator/shared/models/game_wallet.dart';
import 'package:stocksimulator/shared/utils/date_key.dart';

class GamePointReason {
  static const String welcome = 'WELCOME';
  static const String checkin = 'CHECKIN';
  static const String adReward = 'AD_REWARD';
  static const String gameEntry = 'GAME_ENTRY';
  static const String retry = 'RETRY';
  static const String bonus = 'BONUS';
  static const String bet = 'BET';
}

class InsufficientGamePointsException implements Exception {}

class AlreadyCheckedInException implements Exception {}

class GamePointService {
  GamePointService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  static const int welcomePoints = 10000;
  static const int checkInReward = 20;
  static const int adRewardPoints = 30;
  static const int gameEntryCost = 20;

  Stream<GameWallet?> walletStream(String uid) {
    final FirebaseFirestore? firestore = _firestore;
    if (firestore == null || uid.isEmpty) {
      return Stream<GameWallet?>.value(null);
    }

    return firestore.collection('users').doc(uid).snapshots().map((DocumentSnapshot<Map<String, dynamic>> snap) {
      if (!snap.exists) return null;
      return GameWallet.fromFirestore(uid, snap.data() ?? <String, dynamic>{});
    });
  }

  Stream<List<GamePointLedgerEntry>> ledgerStream(String uid, {int limit = 20}) {
    final FirebaseFirestore? firestore = _firestore;
    if (firestore == null || uid.isEmpty) {
      return Stream<List<GamePointLedgerEntry>>.value(const <GamePointLedgerEntry>[]);
    }

    return firestore
        .collection('users')
        .doc(uid)
        .collection('game_point_ledger')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => GamePointLedgerEntry.fromFirestore(doc.data()))
            .toList(growable: false));
  }

  Future<void> ensureWalletInitialized(String uid) {
    return _runDeltaTransaction(
      uid: uid,
      delta: 0,
      reason: null,
      meta: null,
      checkInDateKey: null,
      rejectIfCheckedIn: false,
    );
  }

  Future<void> applyDelta(
    String uid, {
    required int delta,
    required String reason,
    Map<String, dynamic>? meta,
  }) {
    return _runDeltaTransaction(
      uid: uid,
      delta: delta,
      reason: reason,
      meta: meta,
      checkInDateKey: null,
      rejectIfCheckedIn: false,
    );
  }

  Future<void> checkIn(String uid) {
    return _runDeltaTransaction(
      uid: uid,
      delta: checkInReward,
      reason: GamePointReason.checkin,
      meta: null,
      checkInDateKey: DateKey.kstYmd(),
      rejectIfCheckedIn: true,
    );
  }

  Future<void> _runDeltaTransaction({
    required String uid,
    required int delta,
    required String? reason,
    required Map<String, dynamic>? meta,
    required String? checkInDateKey,
    required bool rejectIfCheckedIn,
  }) async {
    final FirebaseFirestore? firestoreMaybe = _firestore;
    if (firestoreMaybe == null) {
      throw Exception('네트워크 오류가 발생했어요');
    }
    final FirebaseFirestore firestore = firestoreMaybe;
    final DocumentReference<Map<String, dynamic>> walletRef = firestore.collection('users').doc(uid);
    final CollectionReference<Map<String, dynamic>> ledgerCol = walletRef.collection('game_point_ledger');

    await firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> walletSnap = await tx.get(walletRef);
      int currentPoints = 0;
      String? previousCheckIn;
      int currentStreak = 0;

      if (!walletSnap.exists) {
        currentPoints = welcomePoints;
        tx.set(walletRef, <String, dynamic>{
          'gamePoints': currentPoints,
          'streak': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        tx.set(ledgerCol.doc(), <String, dynamic>{
          'delta': welcomePoints,
          'balanceAfter': currentPoints,
          'reason': GamePointReason.welcome,
          'meta': <String, dynamic>{'source': 'wallet_init'},
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final Map<String, dynamic> data = walletSnap.data() ?? <String, dynamic>{};
        currentPoints = (data['gamePoints'] as num?)?.toInt() ?? 0;
        previousCheckIn = data['lastCheckInDate'] as String?;
        currentStreak = (data['streak'] as num?)?.toInt() ?? 0;
      }

      if (rejectIfCheckedIn && checkInDateKey != null && previousCheckIn == checkInDateKey) {
        throw AlreadyCheckedInException();
      }

      if (delta < 0 && currentPoints + delta < 0) {
        throw InsufficientGamePointsException();
      }

      if (delta == 0 && reason == null) {
        tx.set(walletRef, <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      final int balanceAfter = currentPoints + delta;
      final bool isCheckIn = reason == GamePointReason.checkin && checkInDateKey != null;
      final int streak = isCheckIn ? (previousCheckIn == checkInDateKey ? currentStreak : currentStreak + 1) : currentStreak;

      tx.set(walletRef, <String, dynamic>{
        'gamePoints': balanceAfter,
        if (isCheckIn) 'lastCheckInDate': checkInDateKey,
        'streak': streak,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(ledgerCol.doc(), <String, dynamic>{
        'delta': delta,
        'balanceAfter': balanceAfter,
        'reason': reason,
        if (meta != null) 'meta': meta,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
