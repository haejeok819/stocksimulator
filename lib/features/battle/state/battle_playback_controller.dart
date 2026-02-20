import 'dart:async';
import 'dart:math';

import 'package:flutter/animation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/features/battle/state/battle_providers.dart';

enum BattlePlaybackStatus { ready, running, paused, ended }

class BattlePlaybackState {
  const BattlePlaybackState({
    required this.status,
    required this.index,
    required this.position,
    required this.speed,
    required this.showCountdown,
    required this.countdown,
  });

  final BattlePlaybackStatus status;
  final int index;
  final double position;
  final double speed;
  final bool showCountdown;
  final int countdown;

  BattlePlaybackState copyWith({
    BattlePlaybackStatus? status,
    int? index,
    double? position,
    double? speed,
    bool? showCountdown,
    int? countdown,
  }) {
    return BattlePlaybackState(
      status: status ?? this.status,
      index: index ?? this.index,
      position: position ?? this.position,
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
            position: 0,
            speed: _defaultSpeed,
            showCountdown: false,
            countdown: 0,
          ),
        );

  static const double _defaultSpeed = 1;
  static const Duration _safeModeFrameInterval = Duration(milliseconds: 20);
  static const Duration _normalModeFrameInterval = Duration(milliseconds: 16);
  static const Duration _safeModeStartDelay = Duration(milliseconds: 120);

  final Ref ref;
  Timer? _countdownTimer;
  Timer? _frameTimer;
  Timer? _pendingStartTimer;

  DateTime? _lastFrameAt;

  bool get _safeMode => ref.read(battleSetupProvider).safeMode;

  void reset() {
    _cancelTimers(resetFrameClock: true);
    state = state.copyWith(
      status: BattlePlaybackStatus.ready,
      index: 0,
      position: 0,
      showCountdown: false,
      countdown: 0,
    );
  }

  void start() {
    _cancelTimers(resetFrameClock: true);
    state = state.copyWith(
      status: BattlePlaybackStatus.ready,
      index: 0,
      position: 0,
      showCountdown: true,
      countdown: 3,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final int current = state.countdown;
      if (current <= 1) {
        timer.cancel();
        _countdownTimer = null;
        state = state.copyWith(showCountdown: false, countdown: 0);
        _runPlayback();
      } else {
        state = state.copyWith(countdown: current - 1);
      }
    });
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed.clamp(0.5, 8).toDouble());
  }

  void pause() {
    _cancelFrameAndPendingTimers(resetFrameClock: true);
    state = state.copyWith(status: BattlePlaybackStatus.paused, showCountdown: false);
  }

  void resume() {
    if (state.status == BattlePlaybackStatus.ended) return;
    _runPlayback();
  }

  void skipToEnd() {
    final AsyncValue<BattleSeriesData> data = ref.read(battleDataProvider);
    final int end = max(0, (data.valueOrNull?.length ?? 1) - 1);
    _cancelFrameAndPendingTimers(resetFrameClock: true);
    state = state.copyWith(
      index: end,
      position: end.toDouble(),
      status: BattlePlaybackStatus.ended,
      showCountdown: false,
      countdown: 0,
    );
  }

  Duration _frameInterval() => _safeMode ? _safeModeFrameInterval : _normalModeFrameInterval;

  double _basePointsPerSecond(int length) {
    if (length <= 252) {
      return _safeMode ? 0.70 : 0.92;
    }
    if (length <= 1260) {
      return _safeMode ? 2.0 : 2.6;
    }
    return _safeMode ? 6.0 : 7.5;
  }

  void _runPlayback() {
    final BattleSeriesData? data = ref.read(battleDataProvider).valueOrNull;
    if (data == null || data.length <= 1) return;

    state = state.copyWith(status: BattlePlaybackStatus.running, showCountdown: false);
    _cancelFrameAndPendingTimers(resetFrameClock: true);

    void launch() {
      _pendingStartTimer = null;
      _frameTimer = Timer.periodic(_frameInterval(), (Timer timer) {
        if (state.status != BattlePlaybackStatus.running) return;
        final DateTime now = DateTime.now();
        final DateTime previous = _lastFrameAt ?? now;
        _lastFrameAt = now;
        final double dtSeconds = max(0, now.difference(previous).inMicroseconds) / 1000000;
        if (dtSeconds <= 0) return;

        final double velocity = _basePointsPerSecond(data.length) * state.speed;
        final double nextPosition = (state.position + (velocity * dtSeconds)).clamp(0, (data.length - 1).toDouble());
        final int nextIndex = nextPosition.floor().clamp(0, data.length - 1);
        final bool ended = nextPosition >= data.length - 1;

        state = state.copyWith(
          position: nextPosition,
          index: nextIndex,
          status: ended ? BattlePlaybackStatus.ended : BattlePlaybackStatus.running,
        );

        if (ended) {
          timer.cancel();
          _frameTimer = null;
        }
      });
    }

    if (_safeMode) {
      _pendingStartTimer = Timer(_safeModeStartDelay, launch);
    } else {
      launch();
    }
  }

  double easedPositionForRender() {
    final double position = state.position;
    final int base = position.floor();
    final double frac = position - base;
    if (state.speed > 1 || frac <= 0) {
      return position;
    }

    final double strength = ((1.0 - state.speed) / 0.5).clamp(0, 1);
    final double easedFrac = Curves.easeInOutSine.transform(frac);
    return base + (frac + ((easedFrac - frac) * strength));
  }

  void _cancelFrameAndPendingTimers({required bool resetFrameClock}) {
    _frameTimer?.cancel();
    _pendingStartTimer?.cancel();
    _frameTimer = null;
    _pendingStartTimer = null;
    if (resetFrameClock) {
      _lastFrameAt = null;
    }
  }

  void _cancelTimers({required bool resetFrameClock}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _cancelFrameAndPendingTimers(resetFrameClock: resetFrameClock);
  }

  @override
  void dispose() {
    _cancelTimers(resetFrameClock: false);
    super.dispose();
  }
}

final battlePlaybackControllerProvider =
    StateNotifierProvider.autoDispose<BattlePlaybackController, BattlePlaybackState>(
      (ref) => BattlePlaybackController(ref),
    );
