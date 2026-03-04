import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stocksimulator/shared/share/services/capture_service.dart';
import 'package:stocksimulator/shared/share/services/share_file_service.dart';
import 'package:stocksimulator/shared/share/share_payload.dart';

class ShareService {
  const ShareService({ShareFileService? shareFileService})
      : _shareFileService = shareFileService ?? const ShareFileService();

  final ShareFileService _shareFileService;

  static const String _defaultFileName = 'share_result.png';
  static const double defaultPixelRatio = 3.0;
  static const double storyPixelRatio = 4.0;

  Future<void> shareSimulationCard(
    GlobalKey boundaryKey,
    SimulationSharePayload payload, {
    double pixelRatio = defaultPixelRatio,
    bool preferShortText = false,
  }) async {
    final String shareText = preferShortText
        ? ShareTextComposer.simulationShort(
            assetName: payload.title,
            percentReturn: payload.returnText,
          )
        : ShareTextComposer.simulation(
            assetName: payload.title,
            percentReturn: payload.returnText,
            initialValue: payload.investText,
            finalValue: payload.finalText,
            dateRange: payload.periodText,
          );

    await _shareWithBoundary(
      boundaryKey: boundaryKey,
      text: shareText,
      pixelRatio: pixelRatio,
      fileName: _defaultFileName,
    );
  }

  Future<void> shareBattleCard(
    GlobalKey boundaryKey,
    BattleSharePayload payload, {
    double pixelRatio = defaultPixelRatio,
    bool preferShortText = false,
  }) async {
    final String shareText = preferShortText
        ? ShareTextComposer.battleShort(
            assetAName: payload.assetAName,
            assetBName: payload.assetBName,
            winnerLabel: payload.winnerLabel,
          )
        : ShareTextComposer.battle(
            assetAName: payload.assetAName,
            assetBName: payload.assetBName,
            assetAReturn: payload.assetAReturnText,
            assetBReturn: payload.assetBReturnText,
            winnerLabel: payload.winnerLabel,
          );

    await _shareWithBoundary(
      boundaryKey: boundaryKey,
      text: shareText,
      pixelRatio: pixelRatio,
      fileName: _defaultFileName,
    );
  }

  Future<void> _shareWithBoundary({
    required GlobalKey boundaryKey,
    required String text,
    required double pixelRatio,
    required String fileName,
  }) async {
    try {
      final Uint8List imageBytes = await CaptureService.capturePng(
        boundaryKey,
        pixelRatio: pixelRatio,
      );
      await shareResult(imageBytes, text, fileName: fileName);
    } catch (_) {
      // 이미지 캡처/저장 실패 시 텍스트만 공유 폴백
      await _shareTextOnly(text);
    }
  }

  Future<void> shareResult(
    Uint8List imageBytes,
    String text, {
    String fileName = _defaultFileName,
  }) async {
    try {
      final XFile imageFile = await _shareFileService.saveTempPng(
        imageBytes,
        prefix: 'result_share',
        fileName: fileName,
      );

      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: <XFile>[imageFile],
        ),
      );
    } catch (_) {
      // 최신 API 또는 파일 공유 실패 시 텍스트만 공유
      await _shareTextOnly(text);
    }
  }

  Future<void> _shareTextOnly(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
