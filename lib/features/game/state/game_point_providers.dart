import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/models/game_point_ledger_entry.dart';
import 'package:stocksimulator/shared/models/game_wallet.dart';
import 'package:stocksimulator/shared/services/firebase_runtime.dart';
import 'package:stocksimulator/shared/services/game_point_service.dart';

final Provider<GamePointService> gamePointServiceProvider = Provider<GamePointService>((Ref ref) {
  final bool isSupportedPlatform = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (!FirebaseRuntime.isReady || !isSupportedPlatform) {
    return GamePointService();
  }
  return GamePointService(firestore: FirebaseFirestore.instance);
});

final StreamProvider<GameWallet?> gameWalletProvider = StreamProvider<GameWallet?>((Ref ref) {
  final String? uid = ref.watch(authControllerProvider).user?.uid;
  if (uid == null || uid.isEmpty) return Stream<GameWallet?>.value(null);
  return ref.watch(gamePointServiceProvider).walletStream(uid);
});

final StreamProvider<List<GamePointLedgerEntry>> gameLedgerProvider =
    StreamProvider<List<GamePointLedgerEntry>>((Ref ref) {
  final String? uid = ref.watch(authControllerProvider).user?.uid;
  if (uid == null || uid.isEmpty) return Stream<List<GamePointLedgerEntry>>.value(const <GamePointLedgerEntry>[]);
  return ref.watch(gamePointServiceProvider).ledgerStream(uid, limit: 20);
});

final AsyncNotifierProvider<GamePointController, void> gamePointControllerProvider =
    AsyncNotifierProvider<GamePointController, void>(GamePointController.new);

class GamePointController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  GamePointService get _service => ref.read(gamePointServiceProvider);
  String? get _uid => ref.read(authControllerProvider).user?.uid;

  Future<void> initIfNeeded() async {
    final String? uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('로그인 후 이용할 수 있어요');
    }
    state = const AsyncLoading<void>();
    try {
      await _service.ensureWalletInitialized(uid);
      state = const AsyncData<void>(null);
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  Future<void> checkIn() async {
    final String? uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('로그인 후 이용할 수 있어요');
    }
    state = const AsyncLoading<void>();
    try {
      await _service.checkIn(uid);
      state = const AsyncData<void>(null);
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  Future<void> claimAdReward() async {
    final String? uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('로그인 후 이용할 수 있어요');
    }
    state = const AsyncLoading<void>();
    try {
      await _service.applyDelta(uid, delta: GamePointService.adRewardPoints, reason: GamePointReason.adReward);
      state = const AsyncData<void>(null);
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  Future<void> spendForGameEntry() async {
    final String? uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('로그인 후 이용할 수 있어요');
    }
    state = const AsyncLoading<void>();
    try {
      await _service.applyDelta(uid, delta: -GamePointService.gameEntryCost, reason: GamePointReason.gameEntry);
      state = const AsyncData<void>(null);
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }

  Future<void> spendForBet(int betPoints) async {
    final String? uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('로그인 후 이용할 수 있어요');
    }
    state = const AsyncLoading<void>();
    try {
      await _service.applyDelta(uid, delta: -betPoints, reason: GamePointReason.bet, meta: <String, dynamic>{'betPoints': betPoints});
      state = const AsyncData<void>(null);
    } catch (error, stackTrace) {
      state = AsyncError<void>(error, stackTrace);
      rethrow;
    }
  }
}
