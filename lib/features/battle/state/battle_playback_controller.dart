import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';

enum BattlePlaybackStatus { ready, running, paused, ended }

class BattlePlaybackState {
  const BattlePlaybackState({
    required this.status,
    required this.index,
    required this.speed,
    required this.showCountdown,
    required this.countdown,
  });

  final BattlePlaybackStatus status;
  final int index;
  final double speed;
  final bool showCountdown;
  final int countdown;

  BattlePlaybackState copyWith({
    BattlePlaybackStatus? status,
    int? index,
    double? speed,
    bool? showCountdown,
    int? countdown,
  }) {
    return BattlePlaybackState(
      status: status ?? this.status,
      index: index ?? this.index,
      speed: speed ?? this.speed,
      showCountdown: showCountdown ?? this.showCountdown,
      countdown: countdown ?? this.countdown,
    );
  }
}

class BattlePlaybackController extends StateNotifier<BattlePlaybackState> {
  BattlePlaybackController(this.ref)
      : super(
          const BattlePlaybackState(
            status: BattlePlaybackStatus.ready,
            index: 0,
            speed: 1,
            showCountdown: false,
            countdown: 0,
          ),
        );

  final Ref ref;
  Timer? _countdownTimer;
  Timer? _playbackTimer;
  Timer? _pendingStartTimer;
  int _tickCounter = 0;

  bool get _safeMode => ref.read(battleSetupProvider).safeMode;

  void reset() {
    _countdownTimer?.cancel();
    _playbackTimer?.cancel();
    _pendingStartTimer?.cancel();
    _tickCounter = 0;
    state = state.copyWith(status: BattlePlaybackStatus.ready, index: 0, showCountdown: false, countdown: 0);
  }

  void start() {
    _countdownTimer?.cancel();
    _playbackTimer?.cancel();
    state = state.copyWith(
      status: BattlePlaybackStatus.ready,
      index: 0,
      showCountdown: true,
      countdown: 3,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final int current = state.countdown;
      if (current <= 1) {
        timer.cancel();
        state = state.copyWith(showCountdown: false, countdown: 0);
        _runPlayback();
      } else {
        state = state.copyWith(countdown: current - 1);
      }
    });
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed.clamp(1, 5).toDouble());
    if (state.status == BattlePlaybackStatus.running) {
      _playbackTimer?.cancel();
      _runPlayback();
    }
  }

  void pause() {
    _playbackTimer?.cancel();
    _pendingStartTimer?.cancel();
    _playbackTimer = null;
    state = state.copyWith(status: BattlePlaybackStatus.paused, showCountdown: false);
  }

  void resume() {
    if (state.status == BattlePlaybackStatus.ended) return;
    _runPlayback();
  }

  void skipToEnd() {
    final AsyncValue<BattleSeriesData> data = ref.read(battleDataProvider);
    final int end = max(0, (data.valueOrNull?.length ?? 1) - 1);
    _playbackTimer?.cancel();
    _pendingStartTimer?.cancel();
    _playbackTimer = null;
    state = state.copyWith(index: end, status: BattlePlaybackStatus.ended, showCountdown: false, countdown: 0);
  }

  void _runPlayback() {
    final BattleSeriesData? data = ref.read(battleDataProvider).valueOrNull;
    if (data == null || data.length <= 1) return;

    final int intervalMs = _safeMode ? 160 : 32;
    final int step = _safeMode ? max(1, state.speed.round()) : max(1, state.speed.round());

    state = state.copyWith(status: BattlePlaybackStatus.running, showCountdown: false);
    _playbackTimer?.cancel();
    _pendingStartTimer?.cancel();
    _tickCounter = 0;

    void launch() {
      _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (Timer timer) {
        final int next = min(state.index + step, data.length - 1);
        final bool ended = next >= data.length - 1;
        _tickCounter += 1;

        if (!_safeMode || _tickCounter % 2 == 0 || ended) {
          state = state.copyWith(index: next, status: ended ? BattlePlaybackStatus.ended : BattlePlaybackStatus.running);
        } else {
          state = state.copyWith(index: next);
        }

        if (ended) {
          timer.cancel();
          _playbackTimer = null;
        }
      });
    }

    if (_safeMode) {
      _pendingStartTimer = Timer(const Duration(milliseconds: 350), launch);
    } else {
      launch();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _playbackTimer?.cancel();
    _pendingStartTimer?.cancel();
    super.dispose();
  }
}

final battlePlaybackControllerProvider =
StateNotifierProvider.autoDispose<BattlePlaybackController, BattlePlaybackState>(
      (ref) => BattlePlaybackController(ref),
);
