import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Web implementation for clipboard image copying and QR PNG downloading.
/// Completely avoids the Windows Share dialog by directly writing to the system
/// clipboard (navigator.clipboard.write) and opening wa.me directly.
class QrPlatformShare {
  static Uint8List? lastCopiedBytes;
  static Uint8List? lastDownloadedBytes;
  static String? lastDownloadedFileName;

  /// Detects whether the current browser supports writing image blobs to the clipboard.
  static bool canWriteImageToClipboard() {
    try {
      final nav = web.window.navigator;
      final hasClipboard = nav.hasProperty('clipboard'.toJS).toDart;
      final hasClipboardItem = web.window.hasProperty('ClipboardItem'.toJS).toDart;
      return hasClipboard && hasClipboardItem;
    } catch (_) {
      return false;
    }
  }

  /// Copies the raw PNG bytes to the system clipboard as an image/png Blob using ClipboardItem.
  /// Returns true only if the clipboard write was successfully completed.
  static Future<bool> copyImageToClipboard(Uint8List bytes) async {
    lastCopiedBytes = bytes;
    try {
      if (!canWriteImageToClipboard()) {
        return false;
      }

      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
      final clipboardItemConstructor = web.window.getProperty('ClipboardItem'.toJS) as JSFunction;
      final itemData = JSObject();
      itemData.setProperty('image/png'.toJS, blob);
      final clipboardItem = clipboardItemConstructor.callAsConstructor<JSObject>(itemData);

      final nav = web.window.navigator;
      final clipboard = nav.getProperty('clipboard'.toJS) as JSObject;
      final writeFunc = clipboard.getProperty('write'.toJS) as JSFunction;
      final promise = writeFunc.callAsFunction(clipboard, [clipboardItem].toJS) as JSPromise;

      await promise.toDart;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Downloads the actual QR PNG to the user's Downloads folder as a fallback.
  static void downloadImage(Uint8List bytes, String fileName) {
    lastDownloadedBytes = bytes;
    lastDownloadedFileName = fileName;
    try {
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = fileName;
      anchor.style.display = 'none';
      web.document.body?.appendChild(anchor);
      anchor.click();
      anchor.remove();
      web.URL.revokeObjectURL(url);
    } catch (_) {}
  }
}
