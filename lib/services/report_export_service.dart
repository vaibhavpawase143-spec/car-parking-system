import '../core/config/business_profile.dart';
import '../core/utils/formatters.dart';
import 'audit_service.dart';
import 'receipt_print_stub.dart'
    if (dart.library.html) 'receipt_print_web.dart'
    if (dart.library.io) 'receipt_print_mobile.dart';
import 'report_download_stub.dart'
    if (dart.library.html) 'report_download_web.dart'
    if (dart.library.io) 'report_download_mobile.dart';

/// Service responsible for generating and exporting administrative reports to
/// CSV (Excel-compatible with UTF-8 BOM), Print/PDF documents, and 58 mm thermal summaries.
class ReportExportService {
  static final ReportExportService instance = ReportExportService._internal();

  ReportExportService._internal();

  /// Converts tabular data to an RFC-4180 CSV string with UTF-8 BOM.
  static String formatCsv({
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final buffer = StringBuffer();
    // Prepend UTF-8 BOM so Microsoft Excel and Notepad display Marathi & UTF-8 correctly
    buffer.write('\uFEFF');

    String escapeCsvValue(dynamic val) {
      if (val == null) return '';
      final str = val.toString();
      if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
        return '"${str.replaceAll('"', '""')}"';
      }
      return str;
    }

    // Write Header
    buffer.writeln(headers.map(escapeCsvValue).join(','));

    // Write Data Rows
    for (final row in rows) {
      buffer.writeln(row.map(escapeCsvValue).join(','));
    }

    return buffer.toString();
  }

  /// Exports data as a CSV file and triggers platform download.
  Future<bool> exportCsv({
    required String reportTitle,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String? adminUid,
  }) async {
    final csvContent = formatCsv(headers: headers, rows: rows);
    final timestamp = DateTime.now().toIso8601String().substring(0, 10);
    final safeTitle = reportTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final fileName = '${safeTitle}_$timestamp.csv';

    final success = await PlatformReportDownloader.downloadFile(
      fileName: fileName,
      content: csvContent,
      mimeType: 'text/csv;charset=utf-8',
    );

    // Audit log
    try {
      await AuditService.instance.log(
        action: 'EXPORT_REPORT_CSV',
        targetEntity: 'report',
        targetId: reportTitle,
        adminUid: adminUid,
        details: {'fileName': fileName, 'rowCount': rows.length},
      );
    } catch (_) {}

    return success;
  }

  /// Generates a professional print-ready HTML document and opens system print/PDF dialog.
  Future<bool> printReportPdf({
    required String reportTitle,
    required DateTime date,
    required List<String> headers,
    required List<List<dynamic>> rows,
    Map<String, String>? summaryTotals,
    String? adminUid,
  }) async {
    final profile = BusinessProfileController.instance.profile;
    final formattedDate = AppFormatters.formatDate(date);
    final generatedAt = AppFormatters.formatDateTime(DateTime.now());

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$reportTitle - $formattedDate</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 15mm;
    }
    body {
      font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #1e293b;
      margin: 0;
      padding: 10px;
      font-size: 13px;
      line-height: 1.4;
    }
    .header {
      border-bottom: 2px solid #0284c7;
      padding-bottom: 12px;
      margin-bottom: 16px;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
    }
    .biz-title {
      font-size: 20px;
      font-weight: 800;
      color: #0f172a;
      margin: 0 0 4px 0;
    }
    .biz-sub {
      font-size: 12px;
      color: #64748b;
      margin: 0;
    }
    .report-badge {
      text-align: right;
    }
    .report-name {
      font-size: 16px;
      font-weight: 700;
      color: #0284c7;
      margin: 0 0 4px 0;
    }
    .report-meta {
      font-size: 11px;
      color: #64748b;
    }
    .summary-card {
      background: #f8fafc;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 12px 16px;
      margin-bottom: 18px;
      display: flex;
      gap: 24px;
    }
    .summary-item {
      display: flex;
      flex-direction: column;
    }
    .summary-label {
      font-size: 11px;
      color: #64748b;
      text-transform: uppercase;
      font-weight: 600;
    }
    .summary-val {
      font-size: 16px;
      font-weight: 700;
      color: #0f172a;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 8px;
      font-size: 12px;
    }
    th {
      background: #f1f5f9;
      color: #334155;
      font-weight: 700;
      text-align: left;
      padding: 8px 10px;
      border-bottom: 1px solid #cbd5e1;
    }
    td {
      padding: 7px 10px;
      border-bottom: 1px solid #f1f5f9;
    }
    tr:nth-child(even) td {
      background: #fafafa;
    }
    .footer {
      margin-top: 24px;
      padding-top: 8px;
      border-top: 1px solid #e2e8f0;
      font-size: 10px;
      color: #94a3b8;
      display: flex;
      justify-content: space-between;
    }
    @media print {
      body { padding: 0; }
      .no-print { display: none !important; }
    }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <h1 class="biz-title">${profile.businessNameEnglish}</h1>
      <p class="biz-sub">${profile.locationEnglish} • Contact: ${profile.contactPhone}</p>
    </div>
    <div class="report-badge">
      <div class="report-name">$reportTitle</div>
      <div class="report-meta">Date: $formattedDate</div>
      <div class="report-meta">Generated: $generatedAt</div>
    </div>
  </div>

  ${summaryTotals != null && summaryTotals.isNotEmpty ? '''
  <div class="summary-card">
    ${summaryTotals.entries.map((e) => '''
      <div class="summary-item">
        <span class="summary-label">${e.key}</span>
        <span class="summary-val">${e.value}</span>
      </div>
    ''').join('')}
  </div>
  ''' : ''}

  <table>
    <thead>
      <tr>
        ${headers.map((h) => '<th>$h</th>').join('')}
      </tr>
    </thead>
    <tbody>
      ${rows.map((r) => '''
        <tr>
          ${r.map((c) => '<td>${c?.toString() ?? ''}</td>').join('')}
        </tr>
      ''').join('')}
    </tbody>
  </table>

  <div class="footer">
    <span>Car Parking Management System • Confidential Financial Audit</span>
    <span>Page 1 of 1</span>
  </div>
</body>
</html>
''';

    final success = await ReceiptPlatformPrinter.printHtml(html);

    // Audit log
    try {
      await AuditService.instance.log(
        action: 'EXPORT_REPORT_PDF',
        targetEntity: 'report',
        targetId: reportTitle,
        adminUid: adminUid,
        details: {'date': formattedDate, 'rowCount': rows.length},
      );
    } catch (_) {}

    return success;
  }

  /// Prints a 58 mm thermal summary receipt for the daily collection report.
  Future<bool> printThermalSummary({
    required DateTime date,
    required double cash,
    required double upi,
    required double netTotal,
    required int entries,
    required int exits,
    String? adminUid,
  }) async {
    final profile = BusinessProfileController.instance.profile;
    final formattedDate = AppFormatters.formatDate(date);
    final nowStr = AppFormatters.formatTime(DateTime.now());

    final thermalHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    @page { size: 58mm auto; margin: 0; }
    body {
      font-family: monospace;
      width: 40mm;
      max-width: 40mm;
      margin: 0 0 0 2mm;
      padding: 4mm 0;
      font-size: 11px;
      line-height: 1.3;
      color: #000;
      box-sizing: border-box;
    }
    .center { text-align: center; }
    .bold { font-weight: bold; }
    .title { font-size: 13px; font-weight: bold; }
    .divider { border-top: 1px dashed #000; margin: 6px 0; }
    .row { display: flex; justify-content: space-between; }
    .total-row { font-size: 13px; font-weight: bold; margin: 4px 0; }
  </style>
</head>
<body>
  <div class="center title">${profile.businessNameEnglish}</div>
  <div class="center">${profile.locationEnglish}</div>
  <div class="center divider"></div>
  <div class="center bold">DAILY AUDIT REPORT</div>
  <div class="center">Date: $formattedDate</div>
  <div class="center">Printed: $nowStr</div>
  <div class="divider"></div>

  <div class="row"><span>Total Entries:</span><span class="bold">$entries</span></div>
  <div class="row"><span>Total Exits:</span><span class="bold">$exits</span></div>
  <div class="divider"></div>

  <div class="row"><span>Cash Collection:</span><span>${AppFormatters.formatCurrency(cash)}</span></div>
  <div class="row"><span>UPI Collection:</span><span>${AppFormatters.formatCurrency(upi)}</span></div>
  <div class="divider"></div>

  <div class="row total-row"><span>NET TOTAL:</span><span>${AppFormatters.formatCurrency(netTotal)}</span></div>
  <div class="divider"></div>

  <div class="center" style="font-size: 9px; margin-top: 6px;">*** END OF AUDIT SLIP ***</div>
</body>
</html>
''';

    final success = await ReceiptPlatformPrinter.printHtml(thermalHtml);

    try {
      await AuditService.instance.log(
        action: 'PRINT_THERMAL_REPORT',
        targetEntity: 'report',
        targetId: 'Daily Audit Slip',
        adminUid: adminUid,
        details: {'date': formattedDate, 'netTotal': netTotal},
      );
    } catch (_) {}

    return success;
  }
}
