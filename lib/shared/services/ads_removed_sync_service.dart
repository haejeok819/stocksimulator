import 'dart:async';

import 'package:stocksimulator/shared/services/firebase_runtime.dart';
import 'package:stocksimulator/shared/services/user_store.dart';

class AdsRemovedSyncService {
  AdsRemovedSyncService._();

  static final UserStore _userStore = UserStore();

  static Future<bool> syncFromRemoteIfSignedIn({
    required String uid,
    required bool localAdsRemoved,
  }) async {
    if (!FirebaseRuntime.isReady || uid.isEmpty) {
      return localAdsRemoved;
    }

    final bool? remote = await _withRetry<bool?>(() => _userStore.getAdsRemoved(uid), maxAttempts: 4);

    if (remote != null) {
      return remote;
    }

    if (localAdsRemoved) {
      await _withRetry<void>(
        () => _userStore.setAdsRemoved(uid: uid, adsRemoved: true),
        maxAttempts: 4,
      );
    }

    return localAdsRemoved;
  }

  static Future<void> commitAdsRemovedIfSignedIn({required String uid}) async {
    if (!FirebaseRuntime.isReady || uid.isEmpty) {
      return;
    }

    await _withRetry<void>(
      () => _userStore.setAdsRemoved(uid: uid, adsRemoved: true),
      maxAttempts: 4,
    );
  }

  static Future<T> _withRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (attempt == maxAttempts) {
          rethrow;
        }
        final Duration delay = Duration(milliseconds: 250 * attempt);
        await Future<void>.delayed(delay);
      }
    }
    throw lastError ?? StateError('retry failed');
  }
}
