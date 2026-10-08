import 'app_language.dart';
import 'app_language_controller.dart';
import 'app_strings.dart';
import '../../models/notification_model.dart';

/// Centralized localization resolver for in-app notifications.
///
/// Ensures all existing and new notifications display in the active language
/// (English / Marathi) without modifying Firestore records or mutating data.
/// Preserves all dynamic values (names, dates, times, amounts, IDs) untouched.
class NotificationLocalizer {
  /// Localizes the notification title based on the active or provided language.
  static String localizeTitle(NotificationModel notif, {AppLanguage? language}) {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    return localizeRawTitle(notif.title, type: notif.type, language: lang);
  }

  /// Localizes the notification message based on the active or provided language.
  static String localizeMessage(NotificationModel notif, {AppLanguage? language}) {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    return localizeRawMessage(notif.message, type: notif.type, language: lang);
  }

  /// Localizes a category/type tag.
  static String localizeCategory(String type, {AppLanguage? language}) {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final isMr = lang == AppLanguage.marathi;
    final t = type.toLowerCase().trim();

    switch (t) {
      case 'all':
        return AppStrings.all;
      case 'shift':
      case 'shift_alert':
        return isMr ? 'पाळी' : 'Shift';
      case 'cash':
        return isMr ? 'रोख' : 'Cash';
      case 'upi':
        return isMr ? 'युपीआय' : 'UPI';
      case 'handover':
        return isMr ? 'हस्तांतरण' : 'Handover';
      case 'withdrawal':
        return isMr ? 'काढणे' : 'Withdrawal';
      case 'security':
      case 'entry_blocked':
        return isMr ? 'सुरक्षा' : 'Security';
      case 'capacity':
      case 'pass_expiry':
      case 'system':
      default:
        return isMr ? 'सिस्टम' : 'System';
    }
  }

  /// Localizes arbitrary/raw title string.
  static String localizeRawTitle(String rawTitle, {String type = 'system', AppLanguage? language}) {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final isMr = lang == AppLanguage.marathi;
    final trimmed = rawTitle.trim();

    if (trimmed.isEmpty) return trimmed;

    // Direct event key matching (normalizing spaces, hyphens, and casing)
    final normalized = trimmed.toUpperCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    switch (normalized) {
      case 'NEW_SHIFT_ASSIGNED':
      case 'SHIFT_ASSIGNED':
        return isMr ? 'नवीन पाळी नेमणूक' : 'New Shift Assigned';
      case 'SHIFT_UPDATED':
        return isMr ? 'पाळी अद्यतनित केली' : 'Shift Updated';
      case 'SHIFT_CANCELLED':
        return isMr ? 'पाळी रद्द केली' : 'Shift Cancelled';
      case 'SHIFT_STARTED':
        return isMr ? 'पाळी सुरू झाली' : 'Shift Started';
      case 'SHIFT_ENDED':
        return isMr ? 'पाळी समाप्त झाली' : 'Shift Ended';
      case 'SHIFT_ALERT':
        return isMr ? 'पाळी सूचना' : 'Shift Alert';
      case 'SHIFT_REASSIGNED':
        return isMr ? 'पाळी पुनर्नियुक्त केली' : 'Shift Reassigned';
      case 'SHIFT_SCHEDULE_ASSIGNED':
        return isMr ? 'नियमित पाळी वेळापत्रक नियुक्त' : 'Shift Schedule Assigned';
      case 'SHIFT_SCHEDULE_CANCELLED':
        return isMr ? 'नियमित पाळी वेळापत्रक रद्द' : 'Shift Schedule Cancelled';
      case 'SHIFT_CANCELLED_(HOLIDAY_/_SKIPPED)':
      case 'SHIFT_CANCELLED_HOLIDAY_SKIPPED':
      case 'SHIFT_CANCELLED_(HOLIDAY/SKIPPED)':
        return isMr ? 'पाळी रद्द (सुट्टी / वगळली)' : 'Shift Cancelled (Holiday / Skipped)';
      case 'HANDOVER_RECEIVED':
      case 'HANDOVER_INCOMING':
        return isMr ? 'येणारे हस्तांतरण' : 'Incoming Handover';
      case 'HANDOVER_INITIATED':
        return isMr ? 'हस्तांतरण सुरू केले' : 'Handover Initiated';
      case 'HANDOVER_ACCEPTED':
      case 'ACCEPTED:_HANDOVER':
      case 'ACCEPTED_HANDOVER':
        return isMr ? 'स्वीकारले: हस्तांतरण' : 'Accepted: Handover';
      case 'HANDOVER_REJECTED':
      case 'REJECTED:_HANDOVER':
      case 'REJECTED_HANDOVER':
        return isMr ? 'नाकारले: हस्तांतरण' : 'Rejected: Handover';
      case 'HANDOVER_CANCELLED':
      case 'CANCELLED:_HANDOVER':
      case 'CANCELLED_HANDOVER':
        return isMr ? 'हस्तांतरण रद्द केले' : 'Handover Cancelled';
      case 'KEEP_WITH_ME':
        return isMr ? 'रक्षकाकडे ठेवले' : 'Kept by Guard';
      case 'WITHDRAWAL':
        return isMr ? 'काढणे / जमा' : 'Withdrawal';
      case 'CAPACITY_UPDATED':
      case 'PARKING_CAPACITY_UPDATED':
        return isMr ? 'वाहनतळ क्षमता अद्यतनित' : 'Parking Capacity Updated';
      case 'ENTRY_BLOCKED':
      case 'VEHICLE_ENTRY_BLOCKED':
        return isMr ? 'वाहन प्रवेश थांबवला' : 'Vehicle Entry Blocked';
      case 'VEHICLE_ENTRY':
        return isMr ? 'वाहन प्रवेश' : 'Vehicle Entry';
      case 'VEHICLE_EXIT':
        return isMr ? 'वाहन निर्गमन' : 'Vehicle Exit';
      case 'MONTHLY_PASS_CREATED':
      case 'MONTHLY_PASS':
        return isMr ? 'मासिक पास जारी केला' : 'Monthly Pass Created';
      case 'MONTHLY_PASS_RENEWED':
        return isMr ? 'मासिक पास नूतनीकरण' : 'Monthly Pass Renewed';
      case 'PAYMENT_RECEIVED':
      case 'PAYMENT':
        return isMr ? 'पेमेंट प्राप्त झाले' : 'Payment Received';
      case 'SYSTEM':
        return isMr ? 'सिस्टम सूचना' : 'System Notification';
    }

    if (isMr) {
      // 1. Shift titles
      if (trimmed.toLowerCase() == 'new shift assigned' || trimmed.toLowerCase() == 'shift assigned') {
        return 'नवीन पाळी नेमणूक';
      }
      if (trimmed.toLowerCase() == 'shift updated') {
        return 'पाळी अद्यतनित केली';
      }
      if (trimmed.toLowerCase() == 'shift cancelled') {
        return 'पाळी रद्द केली';
      }
      if (trimmed.toLowerCase() == 'shift started') {
        return 'पाळी सुरू झाली';
      }
      if (trimmed.toLowerCase() == 'shift ended') {
        return 'पाळी समाप्त झाली';
      }
      if (trimmed.toLowerCase() == 'shift alert') {
        return 'पाळी सूचना';
      }
      if (trimmed.toLowerCase() == 'shift reassigned') {
        return 'पाळी पुनर्नियुक्त केली';
      }
      if (trimmed.toLowerCase() == 'shift schedule assigned') {
        return 'नियमित पाळी वेळापत्रक नियुक्त';
      }
      if (trimmed.toLowerCase() == 'shift schedule cancelled') {
        return 'नियमित पाळी वेळापत्रक रद्द';
      }
      if (trimmed.toLowerCase().contains('holiday') || trimmed.toLowerCase().contains('skipped')) {
        return 'पाळी रद्द (सुट्टी / वगळली)';
      }

      // 2. Handover titles with dynamic payment type (e.g. Incoming CASH Handover)
      final incHandoverMatch = RegExp(r'^Incoming\s+(\w+)\s+Handover$', caseSensitive: false).firstMatch(trimmed);
      if (incHandoverMatch != null) {
        final pType = incHandoverMatch.group(1)!;
        return 'येणारे $pType हस्तांतरण';
      }

      final initHandoverMatch = RegExp(r'^(\w+)\s+Handover\s+Initiated$', caseSensitive: false).firstMatch(trimmed);
      if (initHandoverMatch != null) {
        final pType = initHandoverMatch.group(1)!;
        return '$pType हस्तांतरण सुरू केले';
      }

      final accHandoverMatch = RegExp(r'^(?:ACCEPTED|Accepted):\s*(\w+)\s*Handover$', caseSensitive: false).firstMatch(trimmed);
      if (accHandoverMatch != null) {
        final pType = accHandoverMatch.group(1)!;
        return 'स्वीकारले: $pType हस्तांतरण';
      }

      final rejHandoverMatch = RegExp(r'^(?:REJECTED|Rejected):\s*(\w+)\s*Handover$', caseSensitive: false).firstMatch(trimmed);
      if (rejHandoverMatch != null) {
        final pType = rejHandoverMatch.group(1)!;
        return 'नाकारले: $pType हस्तांतरण';
      }

      if (trimmed.toLowerCase() == 'handover cancelled') {
        return 'हस्तांतरण रद्द केले';
      }
      if (trimmed.toLowerCase() == 'handover received') {
        return 'हस्तांतरण प्राप्त झाले';
      }

      // 3. Keep with me / Withdrawal
      final keepMatch = RegExp(r'^(\w+)\s+Kept by Guard$', caseSensitive: false).firstMatch(trimmed);
      if (keepMatch != null) {
        final pType = keepMatch.group(1)!;
        return '$pType रक्षकाकडे ठेवले';
      }

      final withMatch = RegExp(r'^(\w+)\s+Withdrawal$', caseSensitive: false).firstMatch(trimmed);
      if (withMatch != null) {
        final pType = withMatch.group(1)!;
        return '$pType जमा / काढणे';
      }

      // 4. Capacity / Security / Pass / Entry
      if (trimmed.toLowerCase() == 'parking capacity updated') {
        return 'वाहनतळ क्षमता अद्यतनित';
      }
      if (trimmed.toLowerCase() == 'vehicle entry blocked' || trimmed.toLowerCase() == 'entry blocked') {
        return 'वाहन प्रवेश थांबवला';
      }
      if (trimmed.toLowerCase() == 'vehicle entry') {
        return 'वाहन प्रवेश';
      }
      if (trimmed.toLowerCase() == 'vehicle exit') {
        return 'वाहन निर्गमन';
      }
      if (trimmed.toLowerCase() == 'monthly pass created') {
        return 'मासिक पास जारी केला';
      }
      if (trimmed.toLowerCase() == 'monthly pass renewed') {
        return 'मासिक पास नूतनीकरण';
      }
      if (trimmed.toLowerCase() == 'payment received') {
        return 'पेमेंट प्राप्त झाले';
      }
    } else {
      // English requested - check if rawTitle is in Marathi
      if (trimmed == 'नवीन पाळी नेमणूक') return 'New Shift Assigned';
      if (trimmed == 'पाळी अद्यतनित केली') return 'Shift Updated';
      if (trimmed == 'पाळी रद्द केली') return 'Shift Cancelled';
      if (trimmed == 'पाळी सुरू झाली') return 'Shift Started';
      if (trimmed == 'पाळी समाप्त झाली') return 'Shift Ended';
      if (trimmed == 'पाळी सूचना') return 'Shift Alert';
      if (trimmed == 'पाळी पुनर्नियुक्त केली') return 'Shift Reassigned';
      if (trimmed == 'नियमित पाळी वेळापत्रक नियुक्त') return 'Shift Schedule Assigned';
      if (trimmed == 'नियमित पाळी वेळापत्रक रद्द') return 'Shift Schedule Cancelled';
      if (trimmed == 'पाळी रद्द (सुट्टी / वगळली)') return 'Shift Cancelled (Holiday / Skipped)';

      final mrIncHandover = RegExp(r'^येणारे\s+(\w+)\s+हस्तांतरण$').firstMatch(trimmed);
      if (mrIncHandover != null) return 'Incoming ${mrIncHandover.group(1)} Handover';

      final mrInitHandover = RegExp(r'^(\w+)\s+हस्तांतरण सुरू केले$').firstMatch(trimmed);
      if (mrInitHandover != null) return '${mrInitHandover.group(1)} Handover Initiated';

      final mrAccHandover = RegExp(r'^स्वीकारले:\s*(\w+)\s*हस्तांतरण$').firstMatch(trimmed);
      if (mrAccHandover != null) return 'Accepted: ${mrAccHandover.group(1)} Handover';

      final mrRejHandover = RegExp(r'^नाकारले:\s*(\w+)\s*हस्तांतरण$').firstMatch(trimmed);
      if (mrRejHandover != null) return 'Rejected: ${mrRejHandover.group(1)} Handover';

      if (trimmed == 'हस्तांतरण रद्द केले') return 'Handover Cancelled';
      if (trimmed == 'हस्तांतरण प्राप्त झाले') return 'Handover Received';

      final mrKeep = RegExp(r'^(\w+)\s+रक्षकाकडे ठेवले$').firstMatch(trimmed);
      if (mrKeep != null) return '${mrKeep.group(1)} Kept by Guard';

      final mrWith = RegExp(r'^(\w+)\s+जमा / काढणे$').firstMatch(trimmed);
      if (mrWith != null) return '${mrWith.group(1)} Withdrawal';

      if (trimmed == 'वाहनतळ क्षमता अद्यतनित') return 'Parking Capacity Updated';
      if (trimmed == 'वाहन प्रवेश थांबवला') return 'Vehicle Entry Blocked';
      if (trimmed == 'वाहन प्रवेश') return 'Vehicle Entry';
      if (trimmed == 'वाहन निर्गमन') return 'Vehicle Exit';
      if (trimmed == 'मासिक पास जारी केला') return 'Monthly Pass Created';
      if (trimmed == 'मासिक पास नूतनीकरण') return 'Monthly Pass Renewed';
      if (trimmed == 'पेमेंट प्राप्त झाले') return 'Payment Received';
    }

    return trimmed;
  }

  /// Localizes arbitrary/raw message string by extracting dynamic parameters.
  static String localizeRawMessage(String rawMsg, {String type = 'system', AppLanguage? language}) {
    final lang = language ?? AppLanguageController.instance.currentLanguage;
    final isMr = lang == AppLanguage.marathi;
    final trimmed = rawMsg.trim();

    if (trimmed.isEmpty) return trimmed;

    if (isMr) {
      // 1. Shift: Assigned with duration
      // "You have been assigned a 8-hour shift on 08/10/2026 from 11:28 AM to 07:28 PM."
      // or "You have been assigned an 8-hour shift on 08/10/2026 from 11:28 AM to 07:28 PM."
      final mShiftAssigned1 = RegExp(
        r'You have been assigned an?\s+(\d+)-hour shift on ([\d/\-]+) from ([\d:]+\s*(?:AM|PM)?) to ([\d:]+\s*(?:AM|PM)?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftAssigned1 != null) {
        final dur = mShiftAssigned1.group(1)!;
        final date = mShiftAssigned1.group(2)!;
        final start = mShiftAssigned1.group(3)!;
        final end = mShiftAssigned1.group(4)!;
        return 'तुम्हाला $date रोजी $start ते $end या वेळेत $dur तासांची पाळी नेमून दिली आहे.';
      }

      // "You have been assigned a shift on 08/10/2026 from 08:00 to 16:00."
      final mShiftAssigned2 = RegExp(
        r'You have been assigned an?\s+shift on ([\d/\-]+) from ([\d:]+\s*(?:AM|PM)?) to ([\d:]+\s*(?:AM|PM)?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftAssigned2 != null) {
        final date = mShiftAssigned2.group(1)!;
        final start = mShiftAssigned2.group(2)!;
        final end = mShiftAssigned2.group(3)!;
        return 'तुम्हाला $date रोजी $start ते $end या वेळेत पाळी नेमून दिली आहे.';
      }

      // 2. Shift: Rescheduled / Updated
      // "Your upcoming shift has been rescheduled to 08/10/2026 from 08:00 AM to 04:00 PM."
      final mShiftUpdated = RegExp(
        r'Your upcoming shift has been rescheduled to ([\d/\-]+) from ([\d:]+\s*(?:AM|PM)?) to ([\d:]+\s*(?:AM|PM)?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftUpdated != null) {
        final date = mShiftUpdated.group(1)!;
        final start = mShiftUpdated.group(2)!;
        final end = mShiftUpdated.group(3)!;
        return 'तुमची आगामी पाळी $date रोजी $start ते $end या वेळेत पुनर्निर्धारित केली आहे.';
      }

      // 3. Shift: Cancelled
      // "Your shift scheduled for 08/10/2026 (08:00 AM - 04:00 PM) has been cancelled."
      final mShiftCancelled = RegExp(
        r'Your shift scheduled for ([\d/\-]+) \(([\d:]+\s*(?:AM|PM)?)\s*-\s*([\d:]+\s*(?:AM|PM)?)\) has been cancelled\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftCancelled != null) {
        final date = mShiftCancelled.group(1)!;
        final start = mShiftCancelled.group(2)!;
        final end = mShiftCancelled.group(3)!;
        return 'तुमची $date ($start - $end) साठी नियोजित पाळी रद्द करण्यात आली आहे.';
      }

      // 4. Shift: Started by Admin
      // "Your shift has been started by Admin (Admin User). Date: 08/10/2026, Start: 08:00 AM."
      final mShiftStartedAdmin = RegExp(
        r'Your shift has been started by Admin \((.+?)\)\.\s*Date:\s*([\d/\-]+),\s*Start:\s*([\d:]+\s*(?:AM|PM)?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftStartedAdmin != null) {
        final admin = mShiftStartedAdmin.group(1)!;
        final date = mShiftStartedAdmin.group(2)!;
        final start = mShiftStartedAdmin.group(3)!;
        return 'तुमची पाळी ॲडमिन ($admin) द्वारे सुरू करण्यात आली आहे. दिनांक: $date, सुरुवात: $start.';
      }

      // 5. Shift: Started (Auto / Self)
      // "Your shift has started. Date: 08/10/2026, Start: 08:00 AM, End: 04:00 PM, Duration: 8 Hours."
      final mShiftStartedAuto = RegExp(
        r'Your shift has started\.\s*Date:\s*([\d/\-]+),\s*Start:\s*([\d:]+\s*(?:AM|PM)?),\s*End:\s*([\d:]+\s*(?:AM|PM)?),\s*Duration:\s*(\d+)\s*Hours\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftStartedAuto != null) {
        final date = mShiftStartedAuto.group(1)!;
        final start = mShiftStartedAuto.group(2)!;
        final end = mShiftStartedAuto.group(3)!;
        final dur = mShiftStartedAuto.group(4)!;
        return 'तुमची पाळी सुरू झाली आहे. दिनांक: $date, सुरुवात: $start, समाप्ती: $end, कालावधी: $dur तास.';
      }

      // 6. Shift: Ended by Admin
      // "Your shift has been ended by Admin (Admin User). Date: 08/10/2026, End: 04:00 PM."
      final mShiftEndedAdmin = RegExp(
        r'Your shift has been ended by Admin \((.+?)\)\.\s*Date:\s*([\d/\-]+),\s*End:\s*([\d:]+\s*(?:AM|PM)?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftEndedAdmin != null) {
        final admin = mShiftEndedAdmin.group(1)!;
        final date = mShiftEndedAdmin.group(2)!;
        final end = mShiftEndedAdmin.group(3)!;
        return 'तुमची पाळी ॲडमिन ($admin) द्वारे समाप्त करण्यात आली आहे. दिनांक: $date, समाप्ती: $end.';
      }

      // 7. Shift: Ended (Auto / Self)
      // "Your shift has ended. Date: 08/10/2026, Scheduled Start: 08:00 AM, Scheduled End: 04:00 PM, Actual End: 04:05 PM."
      final mShiftEndedAuto = RegExp(
        r'Your shift has ended\.\s*Date:\s*([\d/\-]+),\s*Scheduled Start:\s*([\d:]+\s*(?:AM|PM)?),\s*Scheduled End:\s*([\d:]+\s*(?:AM|PM)?),\s*Actual End:\s*([\d:]+\s*(?:AM|PM)?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftEndedAuto != null) {
        final date = mShiftEndedAuto.group(1)!;
        final sStart = mShiftEndedAuto.group(2)!;
        final sEnd = mShiftEndedAuto.group(3)!;
        final aEnd = mShiftEndedAuto.group(4)!;
        return 'तुमची पाळी समाप्त झाली आहे. दिनांक: $date, नियोजित सुरुवात: $sStart, नियोजित समाप्ती: $sEnd, प्रत्यक्ष समाप्ती: $aEnd.';
      }

      // 8. Shift: Inactive Guard Alert
      // "Next scheduled shift could not be started automatically for Guard John Doe. Guard is inactive."
      final mShiftAlert = RegExp(
        r'Next scheduled shift could not be started automatically for Guard (.+?)\.\s*Guard is inactive\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftAlert != null) {
        final name = mShiftAlert.group(1)!;
        return 'सुरक्षा रक्षक $name साठी पुढील नियोजित पाळी आपोआप सुरू करता आली नाही. रक्षक निष्क्रिय आहे.';
      }

      // 9. Shift: Reassigned
      // "Your shift on 08/10/2026 has been reassigned to John Doe."
      final mShiftReassigned = RegExp(
        r'Your shift on ([\d/\-]+) has been reassigned to (.+?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftReassigned != null) {
        final date = mShiftReassigned.group(1)!;
        final name = mShiftReassigned.group(2)!;
        return 'तुमची $date रोजीची पाळी $name यांना पुनर्नियुक्त करण्यात आली आहे.';
      }

      // 10. Shift: Schedule Assigned
      // "Your recurring shift schedule has been assigned from 08/10/2026 to 15/10/2026 (Mon, Tue, Wed)."
      final mScheduleAssigned = RegExp(
        r'Your recurring shift schedule has been assigned from ([\d/\-]+) to ([\d/\-]+) \((.+?)\)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mScheduleAssigned != null) {
        final start = mScheduleAssigned.group(1)!;
        final end = mScheduleAssigned.group(2)!;
        final days = mScheduleAssigned.group(3)!;
        return 'तुमचे नियमित पाळी वेळापत्रक $start ते $end ($days) पर्यंत नेमून दिले आहे.';
      }

      // 11. Shift: Schedule Cancelled
      // "Your recurring shift schedule (Mon, Tue) has been cancelled by Admin."
      final mScheduleCancelled = RegExp(
        r'Your recurring shift schedule \((.+?)\) has been cancelled by Admin\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mScheduleCancelled != null) {
        final days = mScheduleCancelled.group(1)!;
        return 'तुमचे नियमित पाळी वेळापत्रक ($days) ॲडमिनद्वारे रद्द केले आहे.';
      }

      // 12. Shift: Holiday / Skipped
      // "Your shift on 08/10/2026 has been skipped/cancelled."
      final mShiftSkipped = RegExp(
        r'Your shift on ([\d/\-]+) has been skipped/cancelled\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mShiftSkipped != null) {
        final date = mShiftSkipped.group(1)!;
        return 'तुमची $date रोजीची पाळी वगळण्यात/रद्द करण्यात आली आहे.';
      }

      // 13. Handover: Incoming
      // "John Doe has handed over ₹500.00 CASH responsibility to you."
      final mHandoverInc = RegExp(
        r'(.+?) has handed over (₹?[\d,]+(?:\.\d+)?)\s+(\w+) responsibility to you\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mHandoverInc != null) {
        final fromGuard = mHandoverInc.group(1)!;
        final amt = mHandoverInc.group(2)!;
        final pType = mHandoverInc.group(3)!;
        return '$fromGuard यांनी $amt $pType जबाबदारी तुमच्याकडे हस्तांतरित केली आहे.';
      }

      // 14. Handover: Initiated (Admin view)
      // "John Doe handed over ₹500.00 CASH to Jane Smith."
      final mHandoverInit = RegExp(
        r'(.+?) handed over (₹?[\d,]+(?:\.\d+)?)\s+(\w+) to (.+?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mHandoverInit != null) {
        final fromGuard = mHandoverInit.group(1)!;
        final amt = mHandoverInit.group(2)!;
        final pType = mHandoverInit.group(3)!;
        final toGuard = mHandoverInit.group(4)!;
        return '$fromGuard यांनी $amt $pType जबाबदारी $toGuard यांच्याकडे हस्तांतरित केली.';
      }

      // 15. Handover: Accepted (Guard view)
      // "Jane Smith has accepted your CASH handover of ₹500.00."
      final mHandoverAccGuard = RegExp(
        r'(.+?) has accepted your (\w+) handover of (₹?[\d,]+(?:\.\d+)?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mHandoverAccGuard != null) {
        final guard = mHandoverAccGuard.group(1)!;
        final pType = mHandoverAccGuard.group(2)!;
        final amt = mHandoverAccGuard.group(3)!;
        return '$guard यांनी तुमचे $amt चे $pType हस्तांतरण स्वीकारले आहे.';
      }

      // 16. Handover: Accepted (Admin view)
      // "Jane Smith ACCEPTED the CASH handover of ₹500.00 from John Doe."
      final mHandoverAccAdmin = RegExp(
        r'(.+?)\s+(?:ACCEPTED|Accepted)\s+the\s+(\w+)\s+handover\s+of\s+(₹?[\d,]+(?:\.\d+)?)\s+from\s+(.+?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mHandoverAccAdmin != null) {
        final guard = mHandoverAccAdmin.group(1)!;
        final pType = mHandoverAccAdmin.group(2)!;
        final amt = mHandoverAccAdmin.group(3)!;
        final fromGuard = mHandoverAccAdmin.group(4)!;
        return '$guard यांनी $fromGuard यांच्याकडून आलेले $amt चे $pType हस्तांतरण स्वीकारले.';
      }

      // 17. Handover: Rejected (Guard view)
      // "Jane Smith has rejected your CASH handover of ₹500.00."
      final mHandoverRejGuard = RegExp(
        r'(.+?) has rejected your (\w+) handover of (₹?[\d,]+(?:\.\d+)?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mHandoverRejGuard != null) {
        final guard = mHandoverRejGuard.group(1)!;
        final pType = mHandoverRejGuard.group(2)!;
        final amt = mHandoverRejGuard.group(3)!;
        return '$guard यांनी तुमचे $amt चे $pType हस्तांतरण नाकारले आहे.';
      }

      // 18. Handover: Rejected (Admin view)
      // "Jane Smith REJECTED the CASH handover of ₹500.00 from John Doe."
      final mHandoverRejAdmin = RegExp(
        r'(.+?)\s+(?:REJECTED|Rejected)\s+the\s+(\w+)\s+handover\s+of\s+(₹?[\d,]+(?:\.\d+)?)\s+from\s+(.+?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mHandoverRejAdmin != null) {
        final guard = mHandoverRejAdmin.group(1)!;
        final pType = mHandoverRejAdmin.group(2)!;
        final amt = mHandoverRejAdmin.group(3)!;
        final fromGuard = mHandoverRejAdmin.group(4)!;
        return '$guard यांनी $fromGuard यांच्याकडून आलेले $amt चे $pType हस्तांतरण नाकारले.';
      }

      // 19. Handover: Cancelled
      // "John Doe cancelled the ₹500.00 CASH handover."
      final mHandoverCancel = RegExp(
        r'(.+?) cancelled the (₹?[\d,]+(?:\.\d+)?)\s+(\w+) handover\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mHandoverCancel != null) {
        final fromGuard = mHandoverCancel.group(1)!;
        final amt = mHandoverCancel.group(2)!;
        final pType = mHandoverCancel.group(3)!;
        return '$fromGuard यांनी $amt चे $pType हस्तांतरण रद्द केले.';
      }

      // 20. Keep With Me
      // "John Doe kept ₹500.00 CASH responsibility (Carried Forward)."
      final mKeep = RegExp(
        r'(.+?) kept (₹?[\d,]+(?:\.\d+)?)\s+(\w+) responsibility \(Carried Forward\)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mKeep != null) {
        final guard = mKeep.group(1)!;
        final amt = mKeep.group(2)!;
        final pType = mKeep.group(3)!;
        return '$guard यांनी $amt $pType जबाबदारी स्वतःकडे ठेवली (पुढे नेली).';
      }

      // 21. Withdrawal
      // "Admin withdrew ₹500.00 CASH from your responsibility.\nRemaining CASH responsibility: ₹200.00\nDate: 08/10/2026 02:30 PM"
      final mWithdrawal = RegExp(
        r'Admin withdrew (₹?[\d,]+(?:\.\d+)?)\s+(\w+) from your responsibility\.\s*(?:Remaining|उर्वरित)\s*\w*\s*responsibility:\s*(₹?[\d,]+(?:\.\d+)?)\s*(?:Date|दिनांक):\s*(.+)',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mWithdrawal != null) {
        final amt = mWithdrawal.group(1)!;
        final pType = mWithdrawal.group(2)!;
        final rem = mWithdrawal.group(3)!;
        final date = mWithdrawal.group(4)!;
        return 'ॲडमिनने तुमच्या जबाबदारीतून $amt $pType जमा/कमी केले.\nउर्वरित $pType जबाबदारी: $rem\nदिनांक: $date';
      }


      // 22. Capacity Updated
      // "Parking capacity has been updated by Admin (4W: 20, 2W: 50)."
      final mCapacity = RegExp(
        r'Parking capacity has been updated by Admin \(4W:\s*(\d+),\s*2W:\s*(\d+)\)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mCapacity != null) {
        final fourW = mCapacity.group(1)!;
        final twoW = mCapacity.group(2)!;
        return 'ॲडमिनने वाहनतळ क्षमता अद्यतनित केली आहे (4W: $fourW, 2W: $twoW).';
      }

      // 23. Entry Blocked
      if (trimmed == 'No active shift is currently assigned to your account. Vehicle entry cannot be created.' ||
          trimmed.contains('No active shift is currently assigned')) {
        return 'सध्या तुमच्या खात्यावर कोणतीही सक्रिय पाळी नियुक्त केलेली नाही. वाहन प्रवेश नोंदवता येणार नाही.';
      }

      // 24. Vehicle Entry / Exit / Pass
      final mVehicleEntry = RegExp(
        r'Vehicle (.+?) \((.+?)\) entered\. Ticket:\s*(.+?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mVehicleEntry != null) {
        return 'वाहन ${mVehicleEntry.group(1)} (${mVehicleEntry.group(2)}) प्रवेश केला. तिकीट: ${mVehicleEntry.group(3)}.';
      }

      final mVehicleExit = RegExp(
        r'Vehicle (.+?) exited\. Amount paid:\s*(.+?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mVehicleExit != null) {
        return 'वाहन ${mVehicleExit.group(1)} बाहेर पडले. भरलेली रक्कम: ${mVehicleExit.group(2)}.';
      }

      final mPassCreated = RegExp(
        r'Monthly pass (.+?) created for vehicle (.+?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mPassCreated != null) {
        return 'वाहन ${mPassCreated.group(2)} साठी मासिक पास ${mPassCreated.group(1)} तयार केला.';
      }

      final mPassRenewed = RegExp(
        r'Monthly pass (.+?) renewed for vehicle (.+?)\.?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (mPassRenewed != null) {
        return 'वाहन ${mPassRenewed.group(2)} साठी मासिक पास ${mPassRenewed.group(1)} नूतनीकरण केले.';
      }
    } else {
      // English requested - check if rawMsg is in Marathi
      // 1. Shift: Assigned
      final mrShiftAssigned1 = RegExp(
        r'तुम्हाला ([\d/\-]+) रोजी ([\d:]+\s*(?:AM|PM)?) ते ([\d:]+\s*(?:AM|PM)?) या वेळेत (\d+) तासांची पाळी नेमून दिली आहे\.?',
      ).firstMatch(trimmed);
      if (mrShiftAssigned1 != null) {
        final date = mrShiftAssigned1.group(1)!;
        final start = mrShiftAssigned1.group(2)!;
        final end = mrShiftAssigned1.group(3)!;
        final dur = mrShiftAssigned1.group(4)!;
        return 'You have been assigned an $dur-hour shift on $date from $start to $end.';
      }

      final mrShiftAssignedFormatB = RegExp(
        r'तुम्हाला ([\d/\-]+) रोजी (\d+) तासांची पाळी नेमून दिली आहे\.\s*सुरुवात:\s*([\d:]+\s*(?:AM|PM)?),\s*समाप्ती:\s*([\d:]+\s*(?:AM|PM)?)\.?',
      ).firstMatch(trimmed);
      if (mrShiftAssignedFormatB != null) {
        final date = mrShiftAssignedFormatB.group(1)!;
        final dur = mrShiftAssignedFormatB.group(2)!;
        final start = mrShiftAssignedFormatB.group(3)!;
        final end = mrShiftAssignedFormatB.group(4)!;
        return 'You have been assigned an $dur-hour shift on $date from $start to $end.';
      }

      final mrShiftAssigned2 = RegExp(
        r'तुम्हाला ([\d/\-]+) रोजी ([\d:]+\s*(?:AM|PM)?) ते ([\d:]+\s*(?:AM|PM)?) या वेळेत पाळी नेमून दिली आहे\.?',
      ).firstMatch(trimmed);
      if (mrShiftAssigned2 != null) {
        final date = mrShiftAssigned2.group(1)!;
        final start = mrShiftAssigned2.group(2)!;
        final end = mrShiftAssigned2.group(3)!;
        return 'You have been assigned a shift on $date from $start to $end.';
      }

      // 2. Shift: Updated
      final mrShiftUpdated = RegExp(
        r'तुमची आगामी पाळी ([\d/\-]+) रोजी ([\d:]+\s*(?:AM|PM)?) ते ([\d:]+\s*(?:AM|PM)?) या वेळेत पुनर्निर्धारित केली आहे\.?',
      ).firstMatch(trimmed);
      if (mrShiftUpdated != null) {
        return 'Your upcoming shift has been rescheduled to ${mrShiftUpdated.group(1)} from ${mrShiftUpdated.group(2)} to ${mrShiftUpdated.group(3)}.';
      }

      // 3. Shift: Cancelled
      final mrShiftCancelled = RegExp(
        r'तुमची ([\d/\-]+) \(([\d:]+\s*(?:AM|PM)?)\s*-\s*([\d:]+\s*(?:AM|PM)?)\) साठी नियोजित पाळी रद्द करण्यात आली आहे\.?',
      ).firstMatch(trimmed);
      if (mrShiftCancelled != null) {
        return 'Your shift scheduled for ${mrShiftCancelled.group(1)} (${mrShiftCancelled.group(2)} - ${mrShiftCancelled.group(3)}) has been cancelled.';
      }

      // 4. Shift: Started (Admin)
      final mrShiftStartedAdmin = RegExp(
        r'तुमची पाळी ॲडमिन \((.+?)\) द्वारे सुरू करण्यात आली आहे\.\s*दिनांक:\s*([\d/\-]+),\s*सुरुवात:\s*([\d:]+\s*(?:AM|PM)?)\.?',
      ).firstMatch(trimmed);
      if (mrShiftStartedAdmin != null) {
        return 'Your shift has been started by Admin (${mrShiftStartedAdmin.group(1)}). Date: ${mrShiftStartedAdmin.group(2)}, Start: ${mrShiftStartedAdmin.group(3)}.';
      }

      // 5. Shift: Started (Auto)
      final mrShiftStartedAuto = RegExp(
        r'तुमची पाळी सुरू झाली आहे\.\s*दिनांक:\s*([\d/\-]+),\s*सुरुवात:\s*([\d:]+\s*(?:AM|PM)?),\s*समाप्ती:\s*([\d:]+\s*(?:AM|PM)?),\s*कालावधी:\s*(\d+)\s*तास\.?',
      ).firstMatch(trimmed);
      if (mrShiftStartedAuto != null) {
        return 'Your shift has started. Date: ${mrShiftStartedAuto.group(1)}, Start: ${mrShiftStartedAuto.group(2)}, End: ${mrShiftStartedAuto.group(3)}, Duration: ${mrShiftStartedAuto.group(4)} Hours.';
      }

      // 6. Shift: Ended (Admin)
      final mrShiftEndedAdmin = RegExp(
        r'तुमची पाळी ॲडमिन \((.+?)\) द्वारे समाप्त करण्यात आली आहे\.\s*दिनांक:\s*([\d/\-]+),\s*समाप्ती:\s*([\d:]+\s*(?:AM|PM)?)\.?',
      ).firstMatch(trimmed);
      if (mrShiftEndedAdmin != null) {
        return 'Your shift has been ended by Admin (${mrShiftEndedAdmin.group(1)}). Date: ${mrShiftEndedAdmin.group(2)}, End: ${mrShiftEndedAdmin.group(3)}.';
      }

      // 7. Shift: Ended (Auto)
      final mrShiftEndedAuto = RegExp(
        r'तुमची पाळी समाप्त झाली आहे\.\s*दिनांक:\s*([\d/\-]+),\s*नियोजित सुरुवात:\s*([\d:]+\s*(?:AM|PM)?),\s*नियोजित समाप्ती:\s*([\d:]+\s*(?:AM|PM)?),\s*प्रत्यक्ष समाप्ती:\s*([\d:]+\s*(?:AM|PM)?)\.?',
      ).firstMatch(trimmed);
      if (mrShiftEndedAuto != null) {
        return 'Your shift has ended. Date: ${mrShiftEndedAuto.group(1)}, Scheduled Start: ${mrShiftEndedAuto.group(2)}, Scheduled End: ${mrShiftEndedAuto.group(3)}, Actual End: ${mrShiftEndedAuto.group(4)}.';
      }

      // 8. Shift: Inactive Guard Alert
      final mrShiftAlert = RegExp(
        r'सुरक्षा रक्षक (.+?) साठी पुढील नियोजित पाळी आपोआप सुरू करता आली नाही\.\s*रक्षक निष्क्रिय आहे\.?',
      ).firstMatch(trimmed);
      if (mrShiftAlert != null) {
        return 'Next scheduled shift could not be started automatically for Guard ${mrShiftAlert.group(1)}. Guard is inactive.';
      }

      // 9. Shift: Reassigned
      final mrShiftReassigned = RegExp(
        r'तुमची ([\d/\-]+) रोजीची पाळी (.+?) यांना पुनर्नियुक्त करण्यात आली आहे\.?',
      ).firstMatch(trimmed);
      if (mrShiftReassigned != null) {
        return 'Your shift on ${mrShiftReassigned.group(1)} has been reassigned to ${mrShiftReassigned.group(2)}.';
      }

      // 10. Shift: Schedule Assigned
      final mrScheduleAssigned = RegExp(
        r'तुमचे नियमित पाळी वेळापत्रक ([\d/\-]+) ते ([\d/\-]+) \((.+?)\) पर्यंत नेमून दिले आहे\.?',
      ).firstMatch(trimmed);
      if (mrScheduleAssigned != null) {
        return 'Your recurring shift schedule has been assigned from ${mrScheduleAssigned.group(1)} to ${mrScheduleAssigned.group(2)} (${mrScheduleAssigned.group(3)}).';
      }

      // 11. Shift: Schedule Cancelled
      final mrScheduleCancelled = RegExp(
        r'तुमचे नियमित पाळी वेळापत्रक \((.+?)\) ॲडमिनद्वारे रद्द केले आहे\.?',
      ).firstMatch(trimmed);
      if (mrScheduleCancelled != null) {
        return 'Your recurring shift schedule (${mrScheduleCancelled.group(1)}) has been cancelled by Admin.';
      }

      // 12. Shift: Skipped
      final mrShiftSkipped = RegExp(
        r'तुमची ([\d/\-]+) रोजीची पाळी वगळण्यात/रद्द करण्यात आली आहे\.?',
      ).firstMatch(trimmed);
      if (mrShiftSkipped != null) {
        return 'Your shift on ${mrShiftSkipped.group(1)} has been skipped/cancelled.';
      }

      // 13. Handover: Incoming
      final mrHandoverInc = RegExp(
        r'(.+?) यांनी (₹?[\d,.]+) (\w+) जबाबदारी तुमच्याकडे हस्तांतरित केली आहे\.?',
      ).firstMatch(trimmed);
      if (mrHandoverInc != null) {
        return '${mrHandoverInc.group(1)} has handed over ${mrHandoverInc.group(2)} ${mrHandoverInc.group(3)} responsibility to you.';
      }

      // 14. Handover: Initiated
      final mrHandoverInit = RegExp(
        r'(.+?) यांनी (₹?[\d,.]+) (\w+) जबाबदारी (.+?) यांच्याकडे हस्तांतरित केली\.?',
      ).firstMatch(trimmed);
      if (mrHandoverInit != null) {
        return '${mrHandoverInit.group(1)} handed over ${mrHandoverInit.group(2)} ${mrHandoverInit.group(3)} to ${mrHandoverInit.group(4)}.';
      }

      // 15. Handover: Accepted (Guard)
      final mrHandoverAccGuard = RegExp(
        r'(.+?) यांनी तुमचे (₹?[\d,.]+) चे (\w+) हस्तांतरण स्वीकारले आहे\.?',
      ).firstMatch(trimmed);
      if (mrHandoverAccGuard != null) {
        return '${mrHandoverAccGuard.group(1)} has accepted your ${mrHandoverAccGuard.group(3)} handover of ${mrHandoverAccGuard.group(2)}.';
      }

      // 16. Handover: Accepted (Admin)
      final mrHandoverAccAdmin = RegExp(
        r'(.+?) यांनी (.+?) यांच्याकडून आलेले (₹?[\d,.]+) चे (\w+) हस्तांतरण स्वीकारले\.?',
      ).firstMatch(trimmed);
      if (mrHandoverAccAdmin != null) {
        return '${mrHandoverAccAdmin.group(1)} ACCEPTED the ${mrHandoverAccAdmin.group(4)} handover of ${mrHandoverAccAdmin.group(3)} from ${mrHandoverAccAdmin.group(2)}.';
      }

      // 17. Handover: Rejected (Guard)
      final mrHandoverRejGuard = RegExp(
        r'(.+?) यांनी तुमचे (₹?[\d,.]+) चे (\w+) हस्तांतरण नाकारले आहे\.?',
      ).firstMatch(trimmed);
      if (mrHandoverRejGuard != null) {
        return '${mrHandoverRejGuard.group(1)} has rejected your ${mrHandoverRejGuard.group(3)} handover of ${mrHandoverRejGuard.group(2)}.';
      }

      // 18. Handover: Rejected (Admin)
      final mrHandoverRejAdmin = RegExp(
        r'(.+?) यांनी (.+?) यांच्याकडून आलेले (₹?[\d,.]+) चे (\w+) हस्तांतरण नाकारले\.?',
      ).firstMatch(trimmed);
      if (mrHandoverRejAdmin != null) {
        return '${mrHandoverRejAdmin.group(1)} REJECTED the ${mrHandoverRejAdmin.group(4)} handover of ${mrHandoverRejAdmin.group(3)} from ${mrHandoverRejAdmin.group(2)}.';
      }

      // 19. Handover: Cancelled
      final mrHandoverCancel = RegExp(
        r'(.+?) यांनी (₹?[\d,.]+) चे (\w+) हस्तांतरण रद्द केले\.?',
      ).firstMatch(trimmed);
      if (mrHandoverCancel != null) {
        return '${mrHandoverCancel.group(1)} cancelled the ${mrHandoverCancel.group(2)} ${mrHandoverCancel.group(3)} handover.';
      }

      // 20. Keep With Me
      final mrKeep = RegExp(
        r'(.+?) यांनी (₹?[\d,.]+) (\w+) जबाबदारी स्वतःकडे ठेवली \(पुढे नेली\)\.?',
      ).firstMatch(trimmed);
      if (mrKeep != null) {
        return '${mrKeep.group(1)} kept ${mrKeep.group(2)} ${mrKeep.group(3)} responsibility (Carried Forward).';
      }

      // 21. Withdrawal
      final mrWithdrawal = RegExp(
        r'ॲडमिनने तुमच्या जबाबदारीतून (₹?[\d,.]+) (\w+) जमा/कमी केले\.\s*उर्वरित \w* जबाबदारी:\s*(₹?[\d,.]+)\s*दिनांक:\s*(.+)',
      ).firstMatch(trimmed);
      if (mrWithdrawal != null) {
        return 'Admin withdrew ${mrWithdrawal.group(1)} ${mrWithdrawal.group(2)} from your responsibility.\nRemaining ${mrWithdrawal.group(2)} responsibility: ${mrWithdrawal.group(3)}\nDate: ${mrWithdrawal.group(4)}';
      }

      // 22. Capacity
      final mrCapacity = RegExp(
        r'ॲडमिनने वाहनतळ क्षमता अद्यतनित केली आहे \(4W:\s*(\d+),\s*2W:\s*(\d+)\)\.?',
      ).firstMatch(trimmed);
      if (mrCapacity != null) {
        return 'Parking capacity has been updated by Admin (4W: ${mrCapacity.group(1)}, 2W: ${mrCapacity.group(2)}).';
      }

      // 23. Entry blocked
      if (trimmed.contains('कोणतीही सक्रिय पाळी नियुक्त केलेली नाही')) {
        return 'No active shift is currently assigned to your account. Vehicle entry cannot be created.';
      }
    }

    return trimmed;
  }
}
