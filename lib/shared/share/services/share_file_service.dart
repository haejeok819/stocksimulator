import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareFileService {
  const ShareFileService();

  Future<XFile> saveTempPng(
    Uint8List bytes, {
    required String prefix,
    String? fileName,
  }) async {
    final Directory directory = await getTemporaryDirectory();
    final String resolvedName = fileName ?? _timestampedName(prefix);
    final File file = File('${directory.path}/$resolvedName');
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path);
  }

  String _timestampedName(String prefix) {
    final DateTime now = DateTime.now();
    final String twoDigitMonth = now.month.toString().padLeft(2, '0');
    final String twoDigitDay = now.day.toString().padLeft(2, '0');
    final String twoDigitHour = now.hour.toString().padLeft(2, '0');
    final String twoDigitMinute = now.minute.toString().padLeft(2, '0');
    final String twoDigitSecond = now.second.toString().padLeft(2, '0');
    final String timestamp =
        '${now.year}$twoDigitMonth$twoDigitDay\_$twoDigitHour$twoDigitMinute$twoDigitSecond';
    return '${prefix}_$timestamp.png';
  }
}
