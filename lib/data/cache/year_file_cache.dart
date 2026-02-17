import 'dart:io';
import 'dart:typed_data';

class YearFileCache {
  YearFileCache({Directory? root}) : _root = root ?? Directory('${Directory.systemTemp.path}/stocksim-cache');

  final Directory _root;

  Future<Uint8List?> read(String key) async {
    final File file = File('${_root.path}/$key');
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  Future<void> write(String key, Uint8List bytes) async {
    final File file = File('${_root.path}/$key');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
}
