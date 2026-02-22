import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/auth/auth_state.dart';
import 'package:stocksimulator/shared/services/ad_service.dart';
import 'package:stocksimulator/shared/services/ads_removed_sync_service.dart';
import 'package:stocksimulator/shared/storage/ads_removed_storage.dart';
import 'package:stocksimulator/shared/utils/app_settings.dart';

final AsyncNotifierProvider<AdsRemovedNotifier, bool> adsRemovedProvider =
    AsyncNotifierProvider<AdsRemovedNotifier, bool>(AdsRemovedNotifier.new);

class AdsRemovedNotifier extends AsyncNotifier<bool> {
  static const Duration _autoUnlockDuration = Duration(days: 36500);

  @override
  Future<bool> build() async {
    ref.listen<AuthState>(authControllerProvider, (AuthState? previous, AuthState next) {
      final String? previousUid = previous?.user?.uid;
      final String? nextUid = next.user?.uid;
      if (nextUid != null && nextUid.isNotEmpty && nextUid != previousUid) {
        unawaited(_syncFromRemoteForUser(nextUid));
      }
    });

    final bool adsRemoved = await AdsRemovedStorage.getAdsRemoved();
    _applyAdsRemoved(adsRemoved);

    final String? uid = ref.read(authControllerProvider).user?.uid;
    if (uid != null && uid.isNotEmpty) {
      unawaited(_syncFromRemoteForUser(uid));
    }

    return adsRemoved;
  }

  Future<void> setAdsRemoved(bool value) async {
    state = AsyncData<bool>(value);
    _applyAdsRemoved(value);
    await AdsRemovedStorage.setAdsRemoved(value);

    if (!value) {
      return;
    }

    final String? uid = ref.read(authControllerProvider).user?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }

    try {
      await AdsRemovedSyncService.commitAdsRemovedIfSignedIn(uid: uid);
    } catch (_) {
      // 로컬 true가 유지되므로 서버 동기화 실패는 다음 로그인/실행 때 재시도한다.
    }
  }

  Future<void> _syncFromRemoteForUser(String uid) async {
    final bool local = state.valueOrNull ?? await AdsRemovedStorage.getAdsRemoved();
    try {
      final bool resolved = await AdsRemovedSyncService.syncFromRemoteIfSignedIn(
        uid: uid,
        localAdsRemoved: local,
      );
      state = AsyncData<bool>(resolved);
      _applyAdsRemoved(resolved);
      await AdsRemovedStorage.setAdsRemoved(resolved);
    } catch (_) {
      // 동기화 실패 시 로컬 상태를 유지하고 추후 재시도한다.
    }
  }

  void _applyAdsRemoved(bool adsRemoved) {
    AdService.instance.setAdsRemoved(adsRemoved);
    if (adsRemoved) {
      AppSettings.unlock8xSpeedFor(_autoUnlockDuration);
    }
  }
}
