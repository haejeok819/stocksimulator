import 'package:flutter/services.dart';
import 'package:stocksimulator/shared/share/share_payload.dart';

class ShareLinkService {
  const ShareLinkService._();

  static Future<String> copyAppLink() async {
    await Clipboard.setData(const ClipboardData(text: ShareTextComposer.appLink));
    return '링크가 복사됐어요. 붙여넣기 해주세요.';
  }
}
