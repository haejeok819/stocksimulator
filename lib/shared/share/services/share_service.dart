import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stocksimulator/shared/share/services/capture_service.dart';
import 'package:stocksimulator/shared/share/services/share_file_service.dart';
import 'package:stocksimulator/shared/share/share_payload.dart';

class ShareService {
  const ShareService({CaptureService? captureService, ShareFileService? shareFileService})
      : _captureService = captureService ?? const CaptureService(),
        _shareFileService = shareFileService ?? const ShareFileService();

  final CaptureService _captureService;
  final ShareFileService _shareFileService;

  Future<void> shareSimulationCard(GlobalKey boundaryKey, SimulationSharePayload payload) async {
    final XFile imageFile = await _captureAndSave(boundaryKey, prefix: 'simulation_share');
    await Share.shareXFiles(<XFile>[imageFile], text: '그때 살걸에서 결과 공유 📈\n${payload.returnText}');
  }

  Future<void> shareBattleCard(GlobalKey boundaryKey, BattleSharePayload payload) async {
    final XFile imageFile = await _captureAndSave(boundaryKey, prefix: 'battle_share');
    await Share.shareXFiles(<XFile>[imageFile], text: '그때 살걸에서 결과 공유 📈\n${payload.winnerText}');
  }

  Future<XFile> _captureAndSave(GlobalKey boundaryKey, {required String prefix}) async {
    final bytes = await _captureService.capturePng(boundaryKey);
    return _shareFileService.saveTempPng(bytes, prefix: prefix);
  }
}
