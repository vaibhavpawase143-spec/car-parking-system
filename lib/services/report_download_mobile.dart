import 'dart:io';
import 'package:flutter/foundation.dart';

/// Mobile / Desktop implementation for saving generated reports.
class PlatformReportDownloader {
  static Future<bool> downloadFile({
    required String fileName,
    required String content,
    String mimeType = 'text/csv;charset=utf-8',
  }) async {
    try {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);
      debugPrint('[PlatformReportDownloader] Report saved to temporary file: ${file.path}');
      return true;
    } catch (e) {
      debugPrint('[PlatformReportDownloader] Error writing report file: $e');
      return false;
    }
  }
}
