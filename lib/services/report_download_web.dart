import 'dart:convert';
import 'package:web/web.dart' as web;

/// Web implementation for downloading generated reports (CSV, text).
class PlatformReportDownloader {
  static Future<bool> downloadFile({
    required String fileName,
    required String content,
    String mimeType = 'text/csv;charset=utf-8',
  }) async {
    try {
      final bytes = utf8.encode(content);
      final base64Content = base64Encode(bytes);
      final dataUri = 'data:$mimeType;base64,$base64Content';

      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = dataUri;
      anchor.download = fileName;
      web.document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();
      return true;
    } catch (_) {
      return false;
    }
  }
}
