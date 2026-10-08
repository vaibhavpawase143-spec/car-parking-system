import 'dart:typed_data';

/// Non-web stub for clipboard image copying and QR downloading
/// (used during unit tests and non-web platforms).
class QrPlatformShare {
  static bool mockCanWriteClipboard = true;
  static bool mockClipboardSuccess = true;
  static Uint8List? lastCopiedBytes;
  static Uint8List? lastDownloadedBytes;
  static String? lastDownloadedFileName;

  static bool canWriteImageToClipboard() {
    return mockCanWriteClipboard;
  }

  static Future<bool> copyImageToClipboard(Uint8List bytes) async {
    lastCopiedBytes = bytes;
    return mockClipboardSuccess;
  }

  static void downloadImage(Uint8List bytes, String fileName) {
    lastDownloadedBytes = bytes;
    lastDownloadedFileName = fileName;
  }
}
