import 'package:qr_flutter/qr_flutter.dart';
import '../core/config/business_profile.dart';
import '../core/localization/app_language.dart';
import '../core/localization/app_language_controller.dart';
import '../core/utils/formatters.dart';
import '../models/monthly_pass_model.dart';
import '../models/parking_record_model.dart';
import '../models/vehicle_type.dart';
import 'receipt_print_stub.dart'
    if (dart.library.html) 'receipt_print_web.dart'
    if (dart.library.io) 'receipt_print_mobile.dart';

/// Service for generating and printing 58 mm thermal parking entry receipts.
/// Strictly formatted for 58 mm thermal receipt printers (MPT-II / POS58)
/// with safe printable boundaries (48mm printable head) to eliminate right-edge clipping.
class ReceiptPrintService {
  /// Generates a pure vector SVG QR code string.
  /// 100% crisp at any printer DPI with optimal quiet zone.
  static String generateQrSvg(String data, {int moduleSize = 4, int quietZone = 4}) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final totalModules = moduleCount + (quietZone * 2);
    final totalSize = totalModules * moduleSize;

    final buffer = StringBuffer();
    buffer.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $totalSize $totalSize" width="$totalSize" height="$totalSize">');
    buffer.write('<rect width="100%" height="100%" fill="#ffffff"/>');
    for (int r = 0; r < moduleCount; r++) {
      for (int c = 0; c < moduleCount; c++) {
        if (qrImage.isDark(r, c)) {
          final x = (c + quietZone) * moduleSize;
          final y = (r + quietZone) * moduleSize;
          buffer.write('<rect x="$x" y="$y" width="$moduleSize" height="$moduleSize" fill="#000000"/>');
        }
      }
    }
    buffer.write('</svg>');
    return buffer.toString();
  }

  /// Builds a complete 58 mm thermal receipt HTML document.
  /// Designed specifically for MPT-II / POS58 thermal printers:
  /// - 58 mm page width with 48 mm safe printable area.
  /// - Word-wrapping and min-width: 0 on values to prevent right-edge clipping.
  /// - High-contrast typography optimized for 203 DPI thermal printheads.
  /// - All 14 required data fields without exposing private storage URLs.
  /// - Bilingual: Supports English and Marathi with verified business header & BizFlow branding.
  static String build58mmReceiptHtml(
    ParkingRecord record, {
    AppLanguage? language,
    BusinessProfile? profile,
  }) {
    final p = profile ?? BusinessProfileController.instance.profile;
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final isMarathi = lang == AppLanguage.marathi;

    final qrData = record.qrReference ?? record.ticketNumber;
    final qrSvg = generateQrSvg(qrData, moduleSize: 5, quietZone: 3);

    final normalizedVehicleNumber = AppFormatters.normalizeVehicleNumber(record.vehicleNumber);
    final vehicleType = record.vehicleType.displayName;
    final entryDate = AppFormatters.formatDate(record.entryTime);
    final entryTime = AppFormatters.formatTime(record.entryTime);
    final entryGuard = record.entryGuardName;
    final entryShift = record.entryShift;
    final customerMobile = record.customerMobile.trim().isNotEmpty
        ? record.customerMobile.trim()
        : 'N/A';
    final advancePaid = AppFormatters.formatCurrency(record.advanceAmount);
    final advanceMethod = record.advanceAmount > 0
        ? record.advancePaymentMethod.toUpperCase()
        : 'None';

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Receipt-${record.ticketNumber}</title>
<style>
  @page {
    size: 58mm auto;
    margin: 0;
  }
  @media print {
    html, body {
      width: 58mm !important;
      margin: 0 !important;
      padding: 0 !important;
      background: #fff !important;
      color: #000 !important;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .no-print { display: none !important; }
  }
  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }
  body {
    width: 58mm;
    max-width: 58mm;
    margin: 0 auto;
    padding: 2mm 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, "Courier New", sans-serif;
    color: #000;
    background: #fff;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
    line-height: 1.25;
  }
  .receipt-container {
    width: 40mm;
    max-width: 40mm;
    margin: 0 0 0 2mm;
    padding: 0 1mm;
    box-sizing: border-box;
  }
  .header-shree {
    font-size: 13px;
    font-weight: 800;
    text-align: center;
    color: #000;
  }
  .header-title {
    font-size: 14px;
    font-weight: 900;
    letter-spacing: 0.5px;
    text-align: center;
    margin-bottom: 1px;
    color: #000;
    line-height: 1.2;
  }
  .header-location {
    font-size: 10.5px;
    font-weight: 700;
    text-align: center;
    color: #000;
    margin-bottom: 1px;
  }
  .header-mobile {
    font-size: 10.5px;
    font-weight: 700;
    text-align: center;
    color: #000;
    margin-bottom: 2px;
  }
  .header-subtitle {
    font-size: 11.5px;
    font-weight: 800;
    text-align: center;
    color: #000;
    margin-top: 2px;
    margin-bottom: 3px;
    letter-spacing: 0.5px;
  }
  .divider {
    border-top: 1px dashed #000;
    margin: 3px 0;
    width: 100%;
  }
  .qr-box {
    text-align: center;
    margin: 4px 0 2px 0;
  }
  .qr-box svg {
    display: block;
    margin: 0 auto;
    width: 32mm;
    height: 32mm;
    max-width: 32mm;
    max-height: 32mm;
  }
  .ticket-id {
    font-size: 12px;
    font-weight: 900;
    text-align: center;
    margin: 2px 0 3px 0;
    color: #000;
    word-break: break-word;
    overflow-wrap: anywhere;
  }
  .vehicle-box {
    border: 2px solid #000;
    padding: 4px 2px;
    margin: 4px 0;
    text-align: center;
    border-radius: 3px;
    background: #fff;
  }
  .vehicle-title {
    font-size: 9.5px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: #000;
    margin-bottom: 1px;
  }
  .vehicle-number {
    font-size: 16px;
    font-weight: 900;
    letter-spacing: 1.5px;
    color: #000;
    line-height: 1.2;
  }
  .vehicle-type {
    font-size: 10px;
    font-weight: 700;
    color: #111;
    margin-top: 1px;
  }
  .row {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin: 2px 0;
    font-size: 10px;
    line-height: 1.3;
    width: 100%;
    box-sizing: border-box;
  }
  .label {
    font-weight: 600;
    color: #111;
    white-space: nowrap;
    margin-right: 4px;
    flex-shrink: 0;
  }
  .val {
    font-weight: 800;
    text-align: right;
    color: #000;
    word-break: break-word;
    overflow-wrap: anywhere;
    flex-grow: 1;
    min-width: 0;
  }
  .footer {
    text-align: center;
    font-size: 9.5px;
    font-weight: 600;
    margin-top: 4px;
    margin-bottom: 2mm;
    line-height: 1.3;
    color: #000;
  }
  .bizflow-branding {
    text-align: center;
    font-size: 9px;
    color: #222;
    margin-top: 3px;
    margin-bottom: 2mm;
    line-height: 1.25;
  }
  .bizflow-branding strong {
    font-size: 10.5px;
    letter-spacing: 0.5px;
    color: #000;
  }
</style>
</head>
<body>
  <div class="receipt-container">
    ${isMarathi ? '''
    <div class="header-shree">॥ श्री ॥</div>
    <div class="header-title">${p.marathiName}</div>
    <div class="header-location">${p.marathiLocation}</div>
    <div class="header-mobile">मो. ${p.marathiMobile}</div>
    <div class="header-subtitle">वाहनतळ पावती (प्रवेश पावती)</div>
    ''' : '''
    <div class="header-title">${p.englishName}</div>
    <div class="header-location">${p.englishLocation}</div>
    <div class="header-mobile">Mo. ${p.mobile}</div>
    <div class="header-subtitle">ENTRY RECEIPT</div>
    '''}
    <div class="divider"></div>

    <div class="qr-box">
      $qrSvg
    </div>
    <div class="ticket-id">${isMarathi ? 'पावती क्र.' : 'TICKET'}: ${record.ticketNumber}</div>

    <div class="vehicle-box">
      <div class="vehicle-title">${isMarathi ? 'वाहन क्रमांक' : 'VEHICLE NUMBER'}</div>
      <div class="vehicle-number">$normalizedVehicleNumber</div>
      <div class="vehicle-type">${isMarathi ? 'प्रकार: ${record.vehicleType.displayName == 'Two-Wheeler' ? 'दुचाकी' : 'चारचाकी'}' : 'Vehicle Type: $vehicleType'}</div>
    </div>

    <div class="divider"></div>

    <div class="row"><span class="label">${isMarathi ? 'प्रवेश दिनांक:' : 'Entry Date:'}</span><span class="val">$entryDate</span></div>
    <div class="row"><span class="label">${isMarathi ? 'प्रवेश वेळ:' : 'Entry Time:'}</span><span class="val">$entryTime</span></div>
    <div class="row"><span class="label">${isMarathi ? 'ग्राहक मोबाइल:' : 'Customer Mobile:'}</span><span class="val">${customerMobile == 'N/A' && isMarathi ? 'लागू नाही' : customerMobile}</span></div>
    <div class="row"><span class="label">${isMarathi ? 'आगाऊ रक्कम:' : 'Advance Paid:'}</span><span class="val">$advancePaid</span></div>
    <div class="row"><span class="label">${isMarathi ? 'पेमेंट पद्धत:' : 'Payment:'}</span><span class="val">${advanceMethod == 'CASH' && isMarathi ? 'रोख' : advanceMethod}</span></div>
    <div class="row"><span class="label">${isMarathi ? 'सुरक्षा रक्षक:' : 'Guard:'}</span><span class="val">$entryGuard</span></div>
    <div class="row"><span class="label">${isMarathi ? 'पाळी:' : 'Shift:'}</span><span class="val">$entryShift</span></div>

    <div class="divider"></div>
    <div class="footer">${isMarathi ? 'कृपया ही पावती सांभाळून ठेवा.<br>वाहन बाहेर काढताना आवश्यक.' : 'Please keep this slip safe.<br>Required at vehicle exit.'}</div>
    ${p.bizflowBrandingEnabled ? '''
    <div class="divider"></div>
    <div class="bizflow-branding">
      ${isMarathi ? 'द्वारे संचालित' : 'Powered by'}<br>
      <strong>BIZFLOW</strong><br>
      Parking Management System
    </div>
    ''' : ''}
  </div>
</body>
</html>''';
  }

  /// Triggers 58 mm thermal receipt printing for the given record.
  static Future<bool> print58mmEntrySlip(ParkingRecord record, {AppLanguage? language}) async {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final html = build58mmReceiptHtml(record, language: lang);
    return await ReceiptPlatformPrinter.printEntrySlip(record, html);
  }

  /// Builds a complete 58 mm thermal exit settlement receipt HTML document.
  /// Designed specifically for MPT-II / POS58 thermal printers:
  /// - 58 mm page width with 48 mm safe printable area.
  /// - Complete financial accounting including Gross Charge, Advance, Advance Adjusted, and Refund or Balance Due.
  /// - Full cross-shift audit trail: Entry Guard, Advance Collector, Exit Settlement Guard, Exit Shift.
  /// - Bilingual: Supports English and Marathi with verified business header & BizFlow branding.
  static String build58mmExitReceiptHtml(
    ParkingRecord record, {
    AppLanguage? language,
    BusinessProfile? profile,
  }) {
    final p = profile ?? BusinessProfileController.instance.profile;
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final isMarathi = lang == AppLanguage.marathi;

    final qrData = record.qrReference ?? record.ticketNumber;
    final qrSvg = generateQrSvg(qrData, moduleSize: 5, quietZone: 3);

    final normalizedVehicleNumber = AppFormatters.normalizeVehicleNumber(record.vehicleNumber);
    final vehicleType = record.vehicleType.displayName;
    final entryDateTime = AppFormatters.formatDateTime(record.entryTime);
    final exitDateTime = record.exitTime != null ? AppFormatters.formatDateTime(record.exitTime!) : 'N/A';
    final durationStr = record.exitTime != null
        ? AppFormatters.formatDuration(record.exitTime!.difference(record.entryTime))
        : 'N/A';

    final grossCharge = AppFormatters.formatCurrency(record.grossCharge ?? 0.0);
    final advancePaid = AppFormatters.formatCurrency(record.advanceAmount);
    final hasRefund = (record.refundAmount ?? 0) > 0;
    final hasBalance = (record.balanceDue ?? 0) > 0;
    final paymentMethod = (record.paymentMethod ?? 'CASH').toUpperCase();

    final advanceCollector = record.advanceCollectorGuardName ?? record.entryGuardName;
    final advanceCollectorShift = record.advanceCollectorShift ?? record.entryShift;
    final exitGuard = record.exitGuardName ?? 'Guard';
    final exitShift = record.exitShift ?? 'Shift 1';

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Exit-Receipt-${record.ticketNumber}</title>
<style>
  @page {
    size: 58mm auto;
    margin: 0;
  }
  @media print {
    html, body {
      width: 58mm !important;
      margin: 0 !important;
      padding: 0 !important;
      background: #fff !important;
      color: #000 !important;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .no-print { display: none !important; }
  }
  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }
  body {
    width: 58mm;
    max-width: 58mm;
    margin: 0 auto;
    padding: 2mm 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, "Courier New", sans-serif;
    color: #000;
    background: #fff;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
    line-height: 1.25;
  }
  .receipt-container {
    width: 40mm;
    max-width: 40mm;
    margin: 0 0 0 2mm;
    padding: 0 1mm;
    box-sizing: border-box;
  }
  .header-shree {
    font-size: 13px;
    font-weight: 800;
    text-align: center;
    color: #000;
  }
  .header-title {
    font-size: 14px;
    font-weight: 900;
    letter-spacing: 0.5px;
    text-align: center;
    margin-bottom: 1px;
    color: #000;
    line-height: 1.2;
  }
  .header-location {
    font-size: 10.5px;
    font-weight: 700;
    text-align: center;
    color: #000;
    margin-bottom: 1px;
  }
  .header-mobile {
    font-size: 10.5px;
    font-weight: 700;
    text-align: center;
    color: #000;
    margin-bottom: 2px;
  }
  .header-subtitle {
    font-size: 11.5px;
    font-weight: 800;
    text-align: center;
    color: #000;
    margin-top: 2px;
    margin-bottom: 3px;
    letter-spacing: 0.5px;
  }
  .divider {
    border-top: 1px dashed #000;
    margin: 3px 0;
    width: 100%;
  }
  .qr-box {
    text-align: center;
    margin: 4px 0 2px 0;
  }
  .qr-box svg {
    display: block;
    margin: 0 auto;
    width: 32mm;
    height: 32mm;
    max-width: 32mm;
    max-height: 32mm;
  }
  .ticket-id {
    font-size: 12px;
    font-weight: 900;
    text-align: center;
    margin: 2px 0 3px 0;
    color: #000;
    word-break: break-word;
    overflow-wrap: anywhere;
  }
  .vehicle-box {
    border: 2px solid #000;
    padding: 4px 2px;
    margin: 4px 0;
    text-align: center;
    border-radius: 3px;
    background: #fff;
  }
  .vehicle-title {
    font-size: 9.5px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: #000;
    margin-bottom: 1px;
  }
  .vehicle-number {
    font-size: 16px;
    font-weight: 900;
    letter-spacing: 1.5px;
    color: #000;
    line-height: 1.2;
  }
  .vehicle-type {
    font-size: 10px;
    font-weight: 700;
    color: #111;
    margin-top: 1px;
  }
  .amount-box {
    border: 2px solid #000;
    padding: 4px 2px;
    margin: 4px 0;
    text-align: center;
    border-radius: 3px;
    background: #fff;
  }
  .amount-title {
    font-size: 10px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: #000;
  }
  .amount-val {
    font-size: 18px;
    font-weight: 900;
    color: #000;
    margin-top: 1px;
  }
  .row {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin: 2px 0;
    font-size: 10px;
    line-height: 1.3;
    width: 100%;
    box-sizing: border-box;
  }
  .row.highlight {
    font-size: 11px;
    font-weight: 900;
    border-top: 1px solid #000;
    border-bottom: 1px solid #000;
    padding: 2px 0;
    margin: 3px 0;
  }
  .label {
    font-weight: 600;
    color: #111;
    white-space: nowrap;
    margin-right: 4px;
    flex-shrink: 0;
  }
  .val {
    font-weight: 800;
    text-align: right;
    color: #000;
    word-break: break-word;
    overflow-wrap: anywhere;
    min-width: 0;
  }
  .status-box {
    border: 1px solid #000;
    font-size: 10.5px;
    font-weight: 900;
    text-align: center;
    padding: 3px;
    margin: 4px 0;
    letter-spacing: 0.5px;
  }
  .footer {
    text-align: center;
    font-size: 9.5px;
    font-weight: 600;
    margin-top: 4px;
    margin-bottom: 2mm;
    line-height: 1.3;
    color: #000;
  }
  .bizflow-branding {
    text-align: center;
    font-size: 9px;
    color: #222;
    margin-top: 3px;
    margin-bottom: 2mm;
    line-height: 1.25;
  }
  .bizflow-branding strong {
    font-size: 10.5px;
    letter-spacing: 0.5px;
    color: #000;
  }
</style>
</head>
<body>
  <div class="receipt-container">
    ${isMarathi ? '''
    <div class="header-shree">॥ श्री ॥</div>
    <div class="header-title">${p.marathiName}</div>
    <div class="header-location">${p.marathiLocation}</div>
    <div class="header-mobile">मो. ${p.marathiMobile}</div>
    <div class="header-subtitle">वाहनतळ पावती (बाहेर जाण्याची पावती)</div>
    ''' : '''
    <div class="header-title">${p.englishName}</div>
    <div class="header-location">${p.englishLocation}</div>
    <div class="header-mobile">Mo. ${p.mobile}</div>
    <div class="header-subtitle">EXIT RECEIPT</div>
    '''}
    <div class="divider"></div>

    <div class="qr-box">
      $qrSvg
    </div>
    <div class="ticket-id">${isMarathi ? 'पावती क्र.' : 'TICKET'}: ${record.ticketNumber}</div>

    <div class="vehicle-box">
      <div class="vehicle-title">${isMarathi ? 'वाहन क्रमांक' : 'VEHICLE NUMBER'}</div>
      <div class="vehicle-number">$normalizedVehicleNumber</div>
      <div class="vehicle-type">${isMarathi ? 'प्रकार: ${record.vehicleType.displayName == 'Two-Wheeler' ? 'दुचाकी' : 'चारचाकी'}' : 'Vehicle Type: $vehicleType'}</div>
    </div>

    <div class="divider"></div>

    <div class="row"><span class="label">${isMarathi ? 'प्रवेश दिनांक / वेळ:' : 'Entry Date / Time:'}</span><span class="val">$entryDateTime</span></div>
    <div class="row"><span class="label">${isMarathi ? 'बाहेर पडण्याची वेळ:' : 'Exit Date / Time:'}</span><span class="val">$exitDateTime</span></div>
    <div class="row"><span class="label">${isMarathi ? 'पार्किंग कालावधी:' : 'Parking Duration:'}</span><span class="val">$durationStr</span></div>

    <div class="divider"></div>

    <div class="amount-box">
      <div class="amount-title">${isMarathi ? 'एकूण रक्कम' : 'TOTAL AMOUNT'}</div>
      <div class="amount-val">$grossCharge</div>
    </div>

    ${record.advanceAmount > 0 ? '''
    <div class="row"><span class="label">${isMarathi ? 'आगाऊ भरलेली रक्कम:' : 'Advance Paid:'}</span><span class="val">$advancePaid</span></div>
    <div class="row"><span class="label">${isMarathi ? 'आगाऊ वजावट:' : 'Advance Adjusted:'}</span><span class="val">-$advancePaid</span></div>
    ''' : ''}
    ${hasRefund ? '''
    <div class="row highlight"><span class="label">${isMarathi ? 'परतावा दिलेली रक्कम:' : 'REFUND HANDED BACK:'}</span><span class="val">${AppFormatters.formatCurrency(record.refundAmount!)}</span></div>
    <div class="row"><span class="label">${isMarathi ? 'परतावा पद्धत:' : 'REFUND METHOD:'}</span><span class="val">$paymentMethod</span></div>
    ''' : hasBalance ? '''
    <div class="row highlight"><span class="label">${isMarathi ? 'वसूल केलेली शिल्लक:' : 'BALANCE DUE:'}</span><span class="val">${AppFormatters.formatCurrency(record.balanceDue!)}</span></div>
    <div class="row"><span class="label">${isMarathi ? 'पेमेंट पद्धत:' : 'PAYMENT METHOD:'}</span><span class="val">$paymentMethod</span></div>
    ''' : '''
    <div class="row highlight"><span class="label">${isMarathi ? 'अंतिम रक्कम:' : 'FINAL AMOUNT:'}</span><span class="val">₹0</span></div>
    <div class="row"><span class="label">${isMarathi ? 'पेमेंट पद्धत:' : 'PAYMENT METHOD:'}</span><span class="val">$paymentMethod</span></div>
    '''}

    <div class="divider"></div>

    <div class="row"><span class="label">${isMarathi ? 'प्रवेश रक्षक:' : 'Entry Guard:'}</span><span class="val">${record.entryGuardName} (${record.entryShift})</span></div>
    ${record.advanceAmount > 0 ? '''
    <div class="row"><span class="label">${isMarathi ? 'आगाऊ स्वीकारक:' : 'Advance Collector:'}</span><span class="val">$advanceCollector ($advanceCollectorShift)</span></div>
    ''' : ''}
    <div class="row"><span class="label">${isMarathi ? 'निर्गमन रक्षक:' : 'Exit Guard:'}</span><span class="val">$exitGuard</span></div>
    <div class="row"><span class="label">${isMarathi ? 'निर्गमन पाळी:' : 'Exit Shift:'}</span><span class="val">$exitShift</span></div>

    <div class="divider"></div>
    <div class="status-box">${isMarathi ? 'स्थिती: पूर्ण व बाहेर पडले (SETTLED)' : 'STATUS: SETTLED & EXITED'}</div>
    <div class="footer">${isMarathi ? 'धन्यवाद! पुन्हा भेट द्या.' : 'Thank you! Visit again.'}</div>
    ${p.bizflowBrandingEnabled ? '''
    <div class="divider"></div>
    <div class="bizflow-branding">
      ${isMarathi ? 'द्वारे संचालित' : 'Powered by'}<br>
      <strong>BIZFLOW</strong><br>
      Parking Management System
    </div>
    ''' : ''}
  </div>
</body>
</html>''';
  }

  /// Triggers 58 mm thermal exit receipt printing for the given record.
  static Future<bool> print58mmExitReceipt(ParkingRecord record, {AppLanguage? language}) async {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final html = build58mmExitReceiptHtml(record, language: lang);
    return await ReceiptPlatformPrinter.printExitReceipt(record, html);
  }

  /// Builds a 58 mm thermal receipt HTML document for a Monthly Pass.
  static String buildMonthlyPassReceiptHtml(
    MonthlyPassModel pass, {
    AppLanguage? language,
  }) {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final isMarathi = lang == AppLanguage.marathi;

    final normalizedVehicleNumber = AppFormatters.normalizeVehicleNumber(pass.vehicleNumber);
    final startDateStr = AppFormatters.formatDate(pass.startDate, isMarathi: isMarathi);
    final endDateStr = AppFormatters.formatDate(pass.endDate, isMarathi: isMarathi);

    final vehicleTypeLabel = isMarathi
        ? (pass.vehicleType == VehicleType.twoWheeler ? 'दुचाकी' : 'चारचाकी')
        : pass.vehicleType.displayName;
    final paymentMethodLabel = isMarathi
        ? (pass.paymentMethod.toUpperCase() == 'CASH' ? 'रोख' : 'UPI')
        : pass.paymentMethod.toUpperCase();
    final paymentStatusLabel = isMarathi ? 'भरलेले' : 'PAID';

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Pass-${pass.passNumber}</title>
<style>
  @page {
    size: 58mm auto;
    margin: 0;
  }
  @media print {
    html, body {
      width: 58mm !important;
      margin: 0 !important;
      padding: 0 !important;
      background: #fff !important;
      color: #000 !important;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
  }
  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Noto Sans", Arial, sans-serif;
    font-size: 11px;
    line-height: 1.25;
    background: #fff;
    color: #000;
    display: flex;
    justify-content: center;
  }
  .receipt {
    width: 40mm;
    max-width: 40mm;
    margin: 0 0 0 2mm;
    padding: 2mm 1mm 6mm 1mm;
    box-sizing: border-box;
  }
  .header {
    text-align: center;
    margin-bottom: 2mm;
  }
  .biz-name {
    font-size: 13px;
    font-weight: 800;
    letter-spacing: 0.3px;
  }
  .slip-title {
    font-size: 12px;
    font-weight: 800;
    margin-top: 1.5mm;
    margin-bottom: 1.5mm;
    border-top: 1px dashed #000;
    border-bottom: 1px dashed #000;
    padding: 1.5mm 0;
    letter-spacing: 0.5px;
  }
  .divider {
    border-top: 1px dashed #000;
    margin: 2mm 0;
  }
  .row {
    display: flex;
    justify-content: space-between;
    margin-bottom: 1mm;
    font-size: 10px;
  }
  .row .label {
    color: #333;
    font-weight: 500;
  }
  .row .val {
    font-weight: 700;
    text-align: right;
  }
  .vehicle-box {
    text-align: center;
    border: 1.5px solid #000;
    border-radius: 3px;
    padding: 2mm 1mm;
    margin: 2mm 0;
  }
  .vehicle-number {
    font-size: 15px;
    font-weight: 900;
    letter-spacing: 1.2px;
  }
  .status-box {
    text-align: center;
    background: #000;
    color: #fff;
    font-size: 10px;
    font-weight: 800;
    padding: 1.5mm 0;
    margin: 2mm 0;
    letter-spacing: 0.5px;
  }
  .footer {
    text-align: center;
    font-size: 10px;
    font-weight: 700;
    margin-top: 2mm;
  }
  .bizflow-branding {
    text-align: center;
    font-size: 8px;
    color: #444;
    margin-top: 2mm;
  }
</style>
</head>
<body>
  <div class="receipt">
    <div class="header">
      <div class="biz-name">JAY GANESH PAY & PARK</div>
      <div class="slip-title">${isMarathi ? 'मासिक पास' : 'Monthly Pass'}</div>
    </div>

    <div class="row"><span class="label">${isMarathi ? 'पास क्रमांक:' : 'Pass No:'}</span><span class="val">${pass.passNumber}</span></div>

    <div class="vehicle-box">
      <div class="vehicle-number">$normalizedVehicleNumber</div>
    </div>

    <div class="row"><span class="label">${isMarathi ? 'वाहन प्रकार:' : 'Vehicle Type:'}</span><span class="val">$vehicleTypeLabel</span></div>
    <div class="row"><span class="label">${isMarathi ? 'ग्राहक:' : 'Customer:'}</span><span class="val">${pass.customerName}</span></div>
    <div class="row"><span class="label">${isMarathi ? 'मोबाईल:' : 'Mobile:'}</span><span class="val">${pass.customerMobile}</span></div>

    <div class="divider"></div>

    <div class="row"><span class="label">${isMarathi ? 'वैधता:' : 'Validity:'}</span><span class="val">$startDateStr → $endDateStr</span></div>

    <div class="divider"></div>

    <div class="row"><span class="label">${isMarathi ? 'पास रक्कम:' : 'Pass Amount:'}</span><span class="val">₹${pass.amount.toInt()}</span></div>
    <div class="row"><span class="label">${isMarathi ? 'पेमेंट:' : 'Payment:'}</span><span class="val">$paymentStatusLabel ($paymentMethodLabel)</span></div>
    <div class="row"><span class="label">${isMarathi ? 'वैधतेदरम्यान पार्किंग शुल्क:' : 'Parking Fee During Validity:'}</span><span class="val">₹0</span></div>

    <div class="divider"></div>

    <div class="footer">${isMarathi ? 'धन्यवाद!' : 'Thank You!'}</div>
    <div class="divider"></div>
    <div class="bizflow-branding">
      ${isMarathi ? 'BIZFLOW द्वारे समर्थित' : 'Powered by BIZFLOW'}<br>
      <strong>CAR PARKING SYSTEM</strong>
    </div>
  </div>
</body>
</html>''';
  }

  /// Triggers 58 mm thermal receipt printing for a Monthly Pass.
  static Future<bool> printMonthlyPassReceipt(MonthlyPassModel pass, {AppLanguage? language}) async {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final html = buildMonthlyPassReceiptHtml(pass, language: lang);
    return await ReceiptPlatformPrinter.printHtml(html);
  }
}
