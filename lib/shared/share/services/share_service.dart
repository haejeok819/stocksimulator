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

  static const String _defaultFileName = 'geuttae_salggeol_result.png';
  static const double defaultPixelRatio = 3.0;
  static const double storyPixelRatio = 4.0;

  Future<void> shareSimulationCard(
    GlobalKey boundaryKey,
    SimulationSharePayload payload, {
    double pixelRatio = defaultPixelRatio,
  }) async {
    final Uint8List imageBytes =
        await CaptureService.capturePng(boundaryKey, pixelRatio: pixelRatio);
    final String shareText = ShareTextComposer.simulation(
      assetName: payload.title,
      percentReturn: payload.returnText,
      initialValue: payload.investText,
      finalValue: payload.finalText,
      dateRange: payload.periodText,
    );

    await shareResult(imageBytes, shareText);
  }

  Future<void> shareBattleCard(
    GlobalKey boundaryKey,
    BattleSharePayload payload, {
    double pixelRatio = defaultPixelRatio,
  }) async {
    final Uint8List imageBytes =
        await CaptureService.capturePng(boundaryKey, pixelRatio: pixelRatio);
    final String shareText = ShareTextComposer.battle(
      assetAName: payload.assetAName,
      assetBName: payload.assetBName,
      assetAReturn: payload.assetAReturnText,
      assetBReturn: payload.assetBReturnText,
      winnerLabel: payload.winnerLabel,
    );

    await shareResult(imageBytes, shareText);
  }

  Future<void> shareResult(
    Uint8List imageBytes,
    String text, {
    String fileName = _defaultFileName,
  }) async {
    final XFile imageFile = await _shareFileService.saveTempPng(
      imageBytes,
      prefix: 'result_share',
      fileName: fileName,
    );
    await Share.shareXFiles(<XFile>[imageFile], text: text);
  }
}
