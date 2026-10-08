import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation for 58 mm thermal receipt printing.
/// Uses an invisible iframe to isolate the print layout and prevent printing application UI.
class ReceiptPlatformPrinter {
  static String? lastPrintedHtml;

  static Future<bool> printHtml(String htmlContent) async {
    lastPrintedHtml = htmlContent;
    try {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.style.position = 'fixed';
      iframe.style.right = '0';
      iframe.style.bottom = '0';
      iframe.style.width = '0';
      iframe.style.height = '0';
      iframe.style.border = '0';
      iframe.style.visibility = 'hidden';
      web.document.body?.appendChild(iframe);

      final doc = iframe.contentDocument;
      if (doc != null) {
        doc.open();
        doc.write(htmlContent.toJS);
        doc.close();

        web.window.setTimeout((() {
          try {
            iframe.contentWindow?.focus();
            iframe.contentWindow?.print();
          } finally {
            web.window.setTimeout((() {
              iframe.remove();
            }).toJS, 2000.toJS);
          }
        }).toJS, 250.toJS);
        return true;
      }
    } catch (_) {
      web.window.print();
      return true;
    }
    return false;
  }

  static Future<bool> printEntrySlip(dynamic record, String html) async {
    return await printHtml(html);
  }

  static Future<bool> printExitReceipt(dynamic record, String html) async {
    return await printHtml(html);
  }

  static String? savedPrinterName;
  static String? savedMacAddress;
  static String? lastErrorMessage;

  static Future<bool> isPermissionGranted() async => false;
  static Future<bool> requestPermission() async => false;
  static Future<bool> isConnected() async => false;
  static Future<bool> connect(String mac, {String? printerName}) async => false;
  static Future<bool> disconnect() async => false;
  static Future<List<dynamic>> getPairedPrinters() async => [];
  static Future<bool> printTestReceipt() async => false;
}
