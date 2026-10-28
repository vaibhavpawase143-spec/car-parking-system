import 'app_language.dart';
import 'app_language_controller.dart';

/// Centralized strings repository providing UI and Receipt text
/// in both English and Marathi (मराठी).
///
/// Automatically resolves based on `AppLanguageController.instance.currentLanguage`.
class AppStrings {
  static AppLanguage get _currentLang => AppLanguageController.instance.currentLanguage;
  static bool get _isMarathi => _currentLang == AppLanguage.marathi;
  static void setLanguage(AppLanguage lang) => AppLanguageController.instance.setLanguage(lang);

  // ---------------------------------------------------------------------------
  // APP & BRANDING (Fixed Brand Identifiers - Do NOT translate in Marathi)
  // ---------------------------------------------------------------------------
  static const String appName = 'CAR PARKING SYSTEM';
  static const String companyBrand = 'BIZFLOW';
  static const String adminPortal = 'ADMIN PORTAL';
  static const String guardPortalTitle = 'CAR PARKING SYSTEM';
  static const String browserTitle = 'CAR PARKING SYSTEM | BIZFLOW';

  // ---------------------------------------------------------------------------
  // NAVIGATION & HEADER
  // ---------------------------------------------------------------------------
  static String get dashboard => _isMarathi ? 'डॅशबोर्ड' : 'Dashboard';
  static String get entry => _isMarathi ? 'वाहन प्रवेश' : 'Vehicle Entry';
  static String get active => _isMarathi ? 'सक्रिय पार्किंग' : 'Active Parking';
  static String get exit => _isMarathi ? 'वाहन निर्गमन' : 'Vehicle Exit';
  static String get shift => _isMarathi ? 'माझी पाळी' : 'My Shift';
  static String get settings => _isMarathi ? 'भाषा व सेटिंग्ज' : 'Language & Settings';
  static String get settingsNav => _isMarathi ? 'सेटिंग्ज' : 'Settings';
  static String get more => _isMarathi ? 'अधिक' : 'More';
  static String get moreOptions => _isMarathi ? 'अधिक पर्याय' : 'More Options';
  static String get language => _isMarathi ? 'भाषा' : 'Language';
  static String get status => _isMarathi ? 'स्थिती' : 'Status';
  static String get guard => _isMarathi ? 'सुरक्षा रक्षक' : 'Guard';
  static String get guardOnDuty => _isMarathi ? 'ड्यूटीवरील सुरक्षा रक्षक' : 'Guard on Duty';
  static String get profile => _isMarathi ? 'प्रोफाइल' : 'Profile';
  static String get printer => _isMarathi ? 'प्रिंटर' : 'Printer';
  static String get requiredField => _isMarathi ? 'आवश्यक' : 'Required';
  static String get underDevelopment => _isMarathi ? 'लवकरच येत आहे' : 'Under Development';

  // Common Actions
  static String get ok => _isMarathi ? 'ठीक आहे' : 'OK';
  static String get cancel => _isMarathi ? 'रद्द करा' : 'Cancel';
  static String get save => _isMarathi ? 'जतन करा' : 'Save';
  static String get back => _isMarathi ? 'मागे' : 'Back';
  static String get done => _isMarathi ? 'पूर्ण झाले' : 'Done';
  static String get confirm => _isMarathi ? 'पुष्टी करा' : 'Confirm';
  static String get search => _isMarathi ? 'शोधा' : 'Search';
  static String get close => _isMarathi ? 'बंद करा' : 'Close';
  static String get loading => _isMarathi ? 'लोड होत आहे...' : 'Loading...';
  static String get error => _isMarathi ? 'त्रुटी' : 'Error';
  static String get success => _isMarathi ? 'यशस्वी' : 'Success';
  static String get refresh => _isMarathi ? 'रिफ्रेश करा' : 'Refresh';
  static String get today => _isMarathi ? 'आज' : 'Today';
  static String get delete => _isMarathi ? 'हटवा' : 'Delete';
  static String get apply => _isMarathi ? 'लागू करा' : 'Apply';
  static String get clear => _isMarathi ? 'साफ करा' : 'Clear';
  static String get action => _isMarathi ? 'कृती' : 'Action';

  // Sign Out
  static String get confirmSignOut => _isMarathi ? 'बाहेर पडण्याची पुष्टी करा' : 'Confirm Sign Out';
  static String get signOutConfirmMessage => _isMarathi
      ? 'तुम्हाला खात्री आहे की तुम्ही बाहेर पडू इच्छिता? पुन्हा लॉगिन करण्यासाठी क्रेडेंशियल्स आवश्यक असतील.'
      : 'Are you sure you want to sign out of the Guard Portal? You will need your credentials to log back in.';
  static String get signOut => _isMarathi ? 'बाहेर पडा' : 'Sign Out';

  // ---------------------------------------------------------------------------
  // AUTHENTICATION & LOGIN
  // ---------------------------------------------------------------------------
  static String get signInSubtitle => _isMarathi
      ? 'वाहनतळ व्यवस्थापनासाठी कृपया लॉगिन करा'
      : 'Sign in to access the Guard Parking Portal';
  static String get emailLabel => _isMarathi ? 'ईमेल पत्ता' : 'Email Address';
  static String get emailHint => _isMarathi ? 'guard@parking.com' : 'guard@parking.com';
  static String get emailRequired => _isMarathi ? 'कृपया ईमेल टाका' : 'Please enter your email';
  static String get invalidEmail => _isMarathi ? 'कृपया वैध ईमेल पत्ता टाका' : 'Please enter a valid email address';
  static String get passwordLabel => _isMarathi ? 'पासवर्ड' : 'Password';
  static String get passwordHint => '••••••••';
  static String get passwordRequired => _isMarathi ? 'कृपया पासवर्ड टाका' : 'Please enter your password';
  static String get passwordTooShort => _isMarathi ? 'पासवर्ड किमान ६ अक्षरांचा असावा' : 'Password must be at least 6 characters';
  static String get signIn => _isMarathi ? 'लॉगिन करा' : 'LOGIN';
  static String get forgotPassword => _isMarathi ? 'पासवर्ड विसरलात?' : 'Forgot Password?';
  static String get resetPasswordTitle => _isMarathi ? 'पासवर्ड रीसेट करा' : 'Reset Password';
  static String get resetPasswordSubtitle => _isMarathi
      ? 'तुमचा नोंदणीकृत ईमेल टाका. पासवर्ड रीसेट करण्याची लिंक पाठवली जाईल.'
      : 'Enter your registered email to receive a password reset link.';
  static String get sendResetLink => _isMarathi ? 'रीसेट लिंक पाठवा' : 'Send Reset Link';
  static String get resetLinkSent => _isMarathi
      ? 'पासवर्ड रीसेट लिंक तुमच्या ईमेलवर पाठवली आहे.'
      : 'Password reset link sent to your email.';
  static String get backToLogin => _isMarathi ? 'लॉगिनकडे परत जा' : 'Back to Login';

  // ---------------------------------------------------------------------------
  // DASHBOARD
  // ---------------------------------------------------------------------------
  static String get todayEntries => _isMarathi ? 'आजचा प्रवेश' : "Today's Entries";
  static String get todaysEntries => _isMarathi ? 'आजचा प्रवेश' : "Today's Entries";
  static String get todayExits => _isMarathi ? 'आजचे निर्गमन' : "Today's Exits";
  static String get todaysExits => _isMarathi ? 'आजचे निर्गमन' : "Today's Exits";
  static String get todayCollection => _isMarathi ? 'आजचे संकलन' : "Today's Collection";
  static String get todaysCollection => _isMarathi ? 'आजचे संकलन' : "Today's Collection";
  static String get liveEntryCounter => _isMarathi ? 'थेट प्रवेश संख्या' : 'Live entry counter';
  static String get completedSessions => _isMarathi ? 'पूर्ण झालेली वाहने' : 'Completed sessions';
  static String get cashLabel => _isMarathi ? 'रोख' : 'Cash';
  static String get upiLabel => _isMarathi ? 'UPI' : 'UPI';
  static String get quickActions => _isMarathi ? 'जलद कृती' : 'Quick Actions';
  static String get recentActivity => _isMarathi ? 'अलीकडील पार्किंग हालचाली' : 'Recent Parking Activity';
  static String get noRecentActivity => _isMarathi ? 'कोणतीही हालचाल नाही' : 'No Recent Activity';
  static String get noRecentActivityDesc => _isMarathi ? 'वाहनांच्या नोंदी झाल्यावर येथे दिसतील.' : 'Vehicle entries and exits will appear here.';
  static String get viewAllActive => _isMarathi ? 'सर्व सक्रिय पहा' : 'View All Active';
  static String get dailyCollection => _isMarathi ? 'दैनिक संकलन' : 'Daily Collection';
  static String get monthlyPass => _isMarathi ? 'मासिक पास' : 'Monthly Pass';
  static String get noActivityToday => _isMarathi ? 'आज कोणतीही हालचाल नाही' : 'No Parking Activity Today';
  static String get noActivitySubtitle => _isMarathi
      ? 'वाहने आत किंवा बाहेर आल्यावर त्यांची माहिती येथे दिसेल.'
      : 'When vehicles enter or exit the facility, their live status will be tracked here in real-time.';
  static String get liveTag => _isMarathi ? 'थेट' : 'Live';
  static String get live => _isMarathi ? 'थेट' : 'Live';
  static String get exited => _isMarathi ? 'बाहेर पडलेले' : 'Exited';
  static String get myShift => _isMarathi ? 'माझी पाळी' : 'My Shift';
  static String get startedAt => _isMarathi ? 'सुरू झाले:' : 'Started:';

  // ---------------------------------------------------------------------------
  // CAPACITY INDICATOR
  // ---------------------------------------------------------------------------
  static String get liveCapacity => _isMarathi ? 'थेट वाहनतळ क्षमता' : 'Live Parking Capacity';
  static String get liveParkingCapacity => _isMarathi ? 'थेट वाहनतळ क्षमता' : 'Live Parking Capacity';
  static String get carCategory => _isMarathi ? 'चारचाकी (Car)' : 'Four-Wheeler';
  static String get twoWheelerCategory => _isMarathi ? 'दुचाकी (2-Wheeler)' : 'Two-Wheeler';
  static String get twoWheeler => _isMarathi ? 'दुचाकी' : 'Two-Wheeler';
  static String get fourWheeler => _isMarathi ? 'चारचाकी' : 'Four-Wheeler';
  static String get bikes => _isMarathi ? 'दुचाकी' : 'Two-Wheeler';
  static String get cars => _isMarathi ? 'चारचाकी' : 'Four-Wheeler';
  static String get cash => _isMarathi ? 'रोख (Cash)' : 'Cash';
  static String get upi => _isMarathi ? 'UPI' : 'UPI';
  static String get total => _isMarathi ? 'एकूण' : 'Total';
  static String get totalSlots => _isMarathi ? 'एकूण जागा' : 'Total';
  static String get occupied => _isMarathi ? 'भरलेली' : 'Occupied';
  static String get occupiedSlots => _isMarathi ? 'भरलेली' : 'Occupied';
  static String get available => _isMarathi ? 'उपलब्ध' : 'Available';
  static String get availableSlots => _isMarathi ? 'उपलब्ध' : 'Available';
  static String get fullEntryBlocked => _isMarathi ? 'पूर्ण भरले - प्रवेश बंद' : 'FULL - ENTRY BLOCKED';
  static String get capacityFull => _isMarathi ? 'क्षमता पूर्ण' : 'Capacity Full';
  static String get capacityFullBlocked => _isMarathi ? 'वाहनतळ पूर्ण भरले - प्रवेश बंद' : 'CAPACITY FULL - ENTRY BLOCKED';
  static String occupiedPercent(int percent) => _isMarathi ? '$percent% भरले' : '$percent% Occupied';

  // ---------------------------------------------------------------------------
  // VEHICLE ENTRY MODULE
  // ---------------------------------------------------------------------------
  static String get vehicleEntry => _isMarathi ? 'वाहन प्रवेश' : 'Vehicle Entry';
  static String get newVehicleEntry => _isMarathi ? 'नवीन वाहन प्रवेश' : 'New Vehicle Entry';
  static String get vehicleEntryTitle => _isMarathi ? 'नवीन वाहन प्रवेश' : 'New Vehicle Entry';
  static String get selectVehicleCategory => _isMarathi ? 'वाहन प्रकार निवडा' : 'Select Vehicle Category';
  static String get firstHourRate => _isMarathi ? 'पहिला तास' : '1st hr';
  static String get vehicleAndCustomerDetails => _isMarathi ? 'वाहन व ग्राहक माहिती' : 'Vehicle & Customer Details';
  static String get vehicleNumber => _isMarathi ? 'वाहन क्रमांक' : 'Vehicle Number';
  static String get vehicleNumberLabel => _isMarathi ? 'वाहन क्रमांक' : 'Vehicle Number';
  static String get vehicleNumberHint => _isMarathi ? 'उदा. MH12AB1234' : 'e.g. MH12AB1234';
  static String get vehicleNumberRequired => _isMarathi ? 'कृपया वाहन क्रमांक टाका' : 'Please enter vehicle registration number';
  static String get vehicleNumberInvalid => _isMarathi ? 'अवैध वाहन क्रमांक (उदा. MH12AB1234)' : 'Invalid vehicle registration format (e.g. MH12AB1234)';
  static String get invalidVehicleNumber => _isMarathi ? 'अवैध वाहन क्रमांक (उदा. MH12AB1234)' : 'Invalid vehicle registration format (e.g. MH12AB1234)';
  static String get vehicleType => _isMarathi ? 'वाहन प्रकार' : 'Vehicle Type';
  static String get vehicleTypeLabel => _isMarathi ? 'वाहन प्रकार' : 'Vehicle Type';
  static String get customerMobile => _isMarathi ? 'ग्राहक मोबाइल' : 'Customer Mobile';
  static String get customerMobileLabel => _isMarathi ? 'ग्राहक मोबाइल नंबर' : 'Customer Mobile Number';
  static String get customerMobileHint => _isMarathi ? '१० अंकी मोबाइल नंबर' : '10-digit mobile number';
  static String get customerMobileRequired => _isMarathi ? 'कृपया १० अंकी मोबाइल नंबर टाका' : 'Please enter 10-digit mobile number';
  static String get customerMobileInvalid => _isMarathi ? 'कृपया वैध १० अंकी नंबर टाका (६-९ ने सुरू)' : 'Please enter valid 10-digit number (starting with 6-9)';
  static String get mobileRequired => _isMarathi ? 'कृपया १० अंकी मोबाइल नंबर टाका' : 'Please enter 10-digit mobile number';
  static String get enter10DigitMobile => _isMarathi ? '१० अंकी मोबाइल नंबर टाका' : 'Enter 10-digit mobile number';
  static String get invalidMobile => _isMarathi ? 'ग्राहक मोबाइल नंबर अवैध आहे.' : 'Customer mobile number is invalid.';
  static String get advancePayment => _isMarathi ? 'आगाऊ रक्कम (Advance)' : 'Advance Payment';
  static String get advancePaymentLabel => _isMarathi ? 'आगाऊ रक्कम (Advance)' : 'Advance Payment';
  static String get noAdvance => _isMarathi ? 'आगाऊ नाही (₹०)' : 'No Advance (₹0)';
  static String get advanceCash => _isMarathi ? 'रोख आगाऊ (Cash)' : 'Cash Advance';
  static String get advanceUpi => _isMarathi ? 'UPI आगाऊ' : 'UPI Advance';
  static String get advanceAmountLabel => _isMarathi ? 'आगाऊ रक्कम (₹)' : 'Advance Amount (₹)';
  static String get enterAmount => _isMarathi ? 'रक्कम टाका' : 'Enter amount';
  static String get advancePaid => _isMarathi ? 'आगाऊ भरलेली रक्कम' : 'Advance Paid';
  static String get vehiclePhotoLabel => _isMarathi ? 'वाहनाचा फोटो' : 'Vehicle Photo';
  static String get vehiclePhotoMandatory => _isMarathi ? 'वाहनाचा फोटो (अनिवार्य)' : 'Vehicle Photo (Mandatory)';
  static String get capturePhoto => _isMarathi ? 'कॅमेराने फोटो काढा' : 'Capture Photo';
  static String get tapToCapturePhoto => _isMarathi ? 'फोटो काढण्यासाठी येथे टॅप करा' : 'Tap to capture vehicle photo';
  static String get useCameraDevice => _isMarathi ? 'थेट कॅमेरा उघडा' : 'Opens live camera to capture vehicle & plate';
  static String get photoCaptured => _isMarathi ? 'फोटो घेतला आहे' : 'Photo Captured';
  static String get photoRequired => _isMarathi ? 'कृपया वाहनाचा फोटो काढा' : 'Please capture vehicle photo before submitting';
  static String get mandatoryPhotoRequired => _isMarathi ? 'कृपया वाहनाचा फोटो काढा' : 'Please capture vehicle photo before submitting';
  static String get cameraPermissionRequired => _isMarathi ? 'कॅमेरा परवानगी आवश्यक आहे' : 'Camera permission is required';
  static String get autoCapturedOnConfirm => _isMarathi ? 'प्रवेशाच्या वेळी स्वयंचलित नोंद' : 'Auto-captured on confirm';
  static String get retakePhoto => _isMarathi ? 'पुन्हा फोटो काढा' : 'Retake Photo';
  static String get usePhoto => _isMarathi ? 'हा फोटो वापरा' : 'Use Photo';
  static String get generateTicketButton => _isMarathi ? 'प्रवेश निश्चित करा व पावती बनवा' : 'Confirm Entry & Generate Ticket';
  static String get generateTicketAndConfirm => _isMarathi ? 'प्रवेश निश्चित करा व पावती बनवा' : 'Confirm Entry & Generate Ticket';
  static String get duplicateActiveVehicle => _isMarathi ? 'हे वाहन आधीच पार्किंगमध्ये सक्रिय आहे!' : 'This vehicle is already ACTIVE in the parking lot!';
  static String get vehicleAlreadyParked => _isMarathi ? 'हे वाहन आधीच पार्किंगमध्ये सक्रिय आहे!' : 'This vehicle is already ACTIVE in the parking lot!';
  static String get capacityFullError => _isMarathi ? 'वाहनतळ पूर्ण भरले आहे. प्रवेश देता येत नाही.' : 'Parking capacity is full. Cannot admit vehicle.';

  // Entry Slip & Confirmation
  static String get entryConfirmedTitle => _isMarathi ? 'वाहन प्रवेश यशस्वी!' : 'Vehicle Entry Confirmed!';
  static String get entryConfirmedSubtitle => _isMarathi ? 'वाहन नोंदणी पूर्ण झाली आहे.' : 'Vehicle entry has been recorded.';
  static String get entryReceiptTitle => _isMarathi ? 'प्रवेश पावती' : 'ENTRY RECEIPT';
  static String get entrySlipTitle => _isMarathi ? 'प्रवेश पावती' : 'ENTRY RECEIPT';
  static String get ticketNumber => _isMarathi ? 'तिकीट क्रमांक' : 'Ticket Number';
  static String get ticketLabel => _isMarathi ? 'पावती क्र.' : 'TICKET';
  static String get entryDateLabel => _isMarathi ? 'प्रवेश दिनांक:' : 'Entry Date:';
  static String get entryTimeLabel => _isMarathi ? 'प्रवेश वेळ:' : 'Entry Time:';
  static String get entryDate => _isMarathi ? 'प्रवेश दिनांक' : 'Entry Date';
  static String get entryTime => _isMarathi ? 'प्रवेश वेळ' : 'Entry Time';
  static String get guardLabel => _isMarathi ? 'सुरक्षा रक्षक:' : 'Guard:';
  static String get shiftLabel => _isMarathi ? 'पाळी:' : 'Shift:';
  static String get advancePaidLabel => _isMarathi ? 'आगाऊ भरलेली रक्कम:' : 'Advance Paid:';
  static String get paymentMethodLabel => _isMarathi ? 'पेमेंट पद्धत:' : 'Payment Method:';
  static String get viewSlipAndQr => _isMarathi ? 'प्रवेश पावती व QR पहा' : 'View Entry Slip & QR';
  static String get viewEntrySlip => _isMarathi ? 'प्रवेश पावती पहा' : 'View Entry Slip';
  static String get printEntrySlip => _isMarathi ? 'प्रवेश पावती प्रिंट करा' : 'Print Entry Slip';
  static String get printSlip => _isMarathi ? 'पावती प्रिंट करा' : 'Print Slip';
  static String get printing => _isMarathi ? 'प्रिंट होत आहे...' : 'Printing...';
  static String get sendWhatsApp => _isMarathi ? 'WhatsApp वर पाठवा' : 'Send WhatsApp';
  static String get openingWhatsApp => _isMarathi ? 'WhatsApp उघडत आहे...' : 'Opening WhatsApp...';
  static String get sendWhatsAppSlip => _isMarathi ? 'WhatsApp वर पावती पाठवा' : 'Send WhatsApp Slip';
  static String get opensWhatsAppNotice => _isMarathi
      ? 'ग्राहकाच्या मोबाईलवर WhatsApp संदेश पाठवेल'
      : 'Opens customer WhatsApp chat with ticket details';
  static String get mandatoryPhotoCaptured => _isMarathi ? 'वाहनाचा फोटो घेतला आहे' : 'Mandatory Photo Captured';
  static String get storedSecurely => _isMarathi ? 'क्लाउडवर सुरक्षित साठवले' : 'Stored securely';
  static String get enterAnotherVehicle => _isMarathi ? 'पुढील वाहन नोंदवा' : 'Enter Another Vehicle';
  static String get keepSlipSafe => _isMarathi
      ? 'कृपया ही पावती सांभाळून ठेवा. वाहन बाहेर काढताना आवश्यक.'
      : 'Please keep this slip safe. Required at vehicle exit.';
  static String get slipKeepSafeNotice => _isMarathi
      ? 'कृपया ही पावती सांभाळून ठेवा. वाहन बाहेर काढताना आवश्यक.'
      : 'Please keep this slip safe. Required at vehicle exit.';
  static String get printConfirmation => _isMarathi ? 'प्रिंट पुष्टीकरण' : 'Print Confirmation';
  static String get printConfirmationDesc => _isMarathi
      ? 'पावती यशस्वीरित्या प्रिंट झाली का?'
      : 'Did the slip print successfully from the 58mm printer?';
  static String get cancelRetry => _isMarathi ? 'रद्द करा / पुन्हा प्रयत्न करा' : 'Cancel / Retry';
  static String get yesPrinted => _isMarathi ? 'होय, प्रिंट झाली' : 'Yes, Printed';
  static String get printCancelledNotice => _isMarathi
      ? 'प्रिंट रद्द केले. तुम्ही पुन्हा "पावती प्रिंट करा" वर क्लिक करू शकता.'
      : 'Print cancelled. You can click "Print Slip" to try again.';
  static String get printFailedNotice => _isMarathi
      ? 'प्रिंट अयशस्वी. कृपया ब्लूटूथ प्रिंटर चालू व जोडलेला आहे का ते तपासा.'
      : 'Print failed. Ensure Bluetooth printer is powered on and connected.';
  static String get printSuccessNotice => _isMarathi ? 'पावती यशस्वीरित्या प्रिंट झाली!' : 'Receipt printed successfully!';

  // ---------------------------------------------------------------------------
  // VEHICLE ENTRY — HORIZONTAL SPLIT, SCANNING & CONFIRMATION
  // ---------------------------------------------------------------------------
  static String get cameraScanningTitle => _isMarathi ? 'कॅमेरा व स्कॅनिंग' : 'Camera & Scanning';
  static String get entryFormTitle => _isMarathi ? 'वाहन प्रवेश फॉर्म' : 'Entry Form';
  static String get numberPlate => _isMarathi ? 'नंबर प्लेट' : 'Number Plate';
  static String get scanOcrPlate => _isMarathi ? 'नंबर प्लेट OCR स्कॅन' : 'Scan Plate (OCR)';
  static String get numberPlateFramingGuide => _isMarathi ? 'नंबर प्लेट फ्रेममध्ये ठेवा' : 'Align number plate within the frame';
  static String get scanningForQrAndPlate => _isMarathi ? 'QR कोड व नंबर प्लेट स्कॅन करत आहे...' : 'Scanning for QR Code & Number Plate...';
  static String get liveOcrActive => _isMarathi ? 'थेट OCR चालू आहे: नंबर प्लेट फ्रेममध्ये धरा' : 'Live OCR Active: Align plate in frame';
  static String get verifyingStability => _isMarathi ? 'नंबर प्लेट स्थैर्य तपासत आहे...' : 'Verifying plate stability...';
  static String get liveOcrUnsupportedNotice => _isMarathi ? 'थेट कॅमेरा OCR फक्त Android आणि iOS वर उपलब्ध आहे.' : 'Live camera OCR is supported on Android and iOS devices.';
  static String get scanningActive => _isMarathi ? 'स्कॅनिंग चालू आहे' : 'Scanning Active';
  static String get plateDetectedHighConfidence => _isMarathi ? 'नंबर प्लेट आढळली (उच्च अचूकता)' : 'Plate Detected (High Confidence)';
  static String get plateDetectedLowConfidence => _isMarathi ? 'नंबर प्लेट अचूकता कमी आहे' : 'Plate Detection (Low Confidence)';
  static String get lowConfidenceWarning => _isMarathi ? 'नंबर प्लेट अचूकता कमी आहे. कृपया पुन्हा स्कॅन करा किंवा हाताने नोंदवा.' : 'Plate detection confidence low. Please rescan or enter manually.';
  static String get plateNotClearReposition => _isMarathi
      ? 'नंबर प्लेट स्पष्ट नाही — कृपया प्लेट पुन्हा व्यवस्थित धरा'
      : 'Plate not clear — reposition the plate';
  static String get qrOcrConflictTitle => _isMarathi ? 'QR व OCR मध्ये तफावत आढळली!' : 'QR & OCR Mismatch Detected!';
  static String get qrOcrConflictDesc => _isMarathi ? 'QR आणि स्कॅन केलेल्या नंबर प्लेटमध्ये तफावत आहे. कृपया योग्य नंबर निवडा किंवा दुरुस्त करा:' : 'Conflict detected between QR and OCR plate readings. Please select or correct the number:';
  static String get useQrValue => _isMarathi ? 'QR मूल्य वापरा' : 'Use QR Value';
  static String get useOcrValue => _isMarathi ? 'OCR मूल्य वापरा' : 'Use OCR Value';
  static String get confirmPlate => _isMarathi ? 'नंबर प्लेट पुष्टी करा' : 'Confirm Plate';
  static String get plateConfirmed => _isMarathi ? 'नंबर प्लेट पुष्टी झाली ✓' : 'Plate Confirmed ✓';
  static String get plateConfirmationRequired => _isMarathi ? 'नोंद जतन करण्यापूर्वी नंबर प्लेटची पुष्टी करणे आवश्यक आहे.' : 'Please confirm the number plate before saving entry.';
  static String get numberPlatePhotoLabel => _isMarathi ? 'नंबर प्लेट फोटो' : 'Number Plate Photo';
  static String get numberPlatePhotoRequired => _isMarathi ? 'नंबर प्लेट फोटो आवश्यक आहे' : 'Number plate photo is required';
  static String get numberPlatePhotoOptional => _isMarathi ? 'फोटो पर्यायी आहे' : 'Photo is optional';
  static String get retakePlatePhoto => _isMarathi ? 'प्लेटचा फोटो पुन्हा काढा' : 'Retake Plate Photo';
  static String get autoCapturedOnDetection => _isMarathi ? 'नंबर प्लेट आढळल्यावर आपोआप काढला' : 'Auto-captured on detection';
  static String get vehiclePhotoOptionalLabel => _isMarathi ? 'वाहनाचा फोटो (पर्यायी)' : 'Vehicle Photo (Optional)';
  static String get captureVehiclePhoto => _isMarathi ? 'वाहनाचा फोटो काढा' : 'Capture Vehicle Photo';
  static String get retakeVehiclePhoto => _isMarathi ? 'वाहनाचा फोटो पुन्हा काढा' : 'Retake Vehicle Photo';
  static String get vehiclePhotoCaptured => _isMarathi ? 'वाहनाचा फोटो जोडला आहे' : 'Vehicle photo attached';
  static String get cameraPermissionDeniedTitle => _isMarathi ? 'कॅमेरा परवानगी नाकारली' : 'Camera Permission Denied';
  static String get cameraPermissionDeniedDesc => _isMarathi ? 'कॅमेरा वापरण्याची परवानगी नाकारली आहे. तुम्ही हाताने नंबर टाकू शकता.' : 'Camera permission is required to scan plates. You can still enter details manually.';
  static String get retryPermission => _isMarathi ? 'परवानगी पुन्हा मागा' : 'Retry Permission';
  static String get rescan => _isMarathi ? 'पुन्हा स्कॅन करा' : 'Rescan';
  static String get manualEntry => _isMarathi ? 'हाताने नोंदवा' : 'Manual Entry';
  static String get saveEntryButton => _isMarathi ? 'प्रवेश जतन करा व पावती बनवा' : 'Save Entry & Generate Ticket';
  static String get editPlateNumber => _isMarathi ? 'नंबर बदला' : 'Edit Plate';
  static String get entryFormSettings => _isMarathi ? 'प्रवेश फॉर्म सेटिंग्ज' : 'Entry Form Settings';
  static String get requireNumberPlateLabel => _isMarathi ? 'नंबर प्लेट अनिवार्य' : 'Require Number Plate';
  static String get requireNumberPlateDesc => _isMarathi ? 'चालू असल्यास नंबर प्लेट अनिवार्य असेल' : 'When enabled, number plate is mandatory';
  static String get requirePlatePhotoLabel => _isMarathi ? 'नंबर प्लेट फोटो अनिवार्य' : 'Require Plate Photo';
  static String get requirePlatePhotoDesc => _isMarathi ? 'चालू असल्यास नंबर प्लेट फोटो अनिवार्य असेल' : 'When enabled, plate photo is mandatory';
  static String get requireCustomerMobileLabel => _isMarathi ? 'मोबाईल नंबर अनिवार्य' : 'Require Customer Mobile';
  static String get requireCustomerMobileDesc => _isMarathi ? 'चालू असल्यास ग्राहकाचा मोबाईल अनिवार्य असेल' : 'When enabled, customer mobile is mandatory';
  static String get vehiclePhotoVisibleLabel => _isMarathi ? 'वाहनाचा फोटो पर्याय दाखवा' : 'Show Optional Vehicle Photo';
  static String get vehiclePhotoVisibleDesc => _isMarathi ? 'प्रवेश फॉर्ममध्ये पर्यायी वाहनाचा फोटो पर्याय दाखवतो' : 'Shows optional vehicle photo picker in entry form';

  // ---------------------------------------------------------------------------
  // ACTIVE PARKING DIRECTORY
  // ---------------------------------------------------------------------------
  static String get activeParking => _isMarathi ? 'सक्रिय पार्किंग' : 'Active Parking';
  static String get activeParkingTitle => _isMarathi ? 'सक्रिय पार्किंग सूची' : 'Active Vehicles Directory';
  static String get searchActiveHint => _isMarathi ? 'वाहन क्र. किंवा तिकीट नंबर टाका...' : 'Search vehicle number or ticket...';
  static String get allVehicles => _isMarathi ? 'सर्व वाहने' : 'All Vehicles';
  static String get allVehiclesFilter => _isMarathi ? 'सर्व' : 'All';
  static String get twoWheelerFilter => _isMarathi ? 'दुचाकी' : '2-Wheeler';
  static String get fourWheelerFilter => _isMarathi ? 'चारचाकी' : '4-Wheeler';
  static String get withAdvance => _isMarathi ? 'आगाऊ भरलेले' : 'With Advance';
  static String get noMatchingVehicles => _isMarathi ? 'कोणतेही वाहन सापडले नाही' : 'No matching active vehicles found';
  static String get noActiveVehicles => _isMarathi ? 'सध्या कोणतेही सक्रिय वाहन नाही' : 'No Active Vehicles';
  static String get noActiveVehiclesDesc => _isMarathi ? 'वाहने दाखल झाल्यावर त्यांची माहिती येथे दिसेल.' : 'When vehicles enter the parking facility, they will appear here.';
  static String get parkedFor => _isMarathi ? 'पार्किंग वेळ:' : 'Parked for:';
  static String get parked => _isMarathi ? 'पार्क केलेले' : 'Parked';
  static String get proceedToExit => _isMarathi ? 'निर्गमन करा (Exit)' : 'Proceed to Exit';
  static String get vehicleDetails => _isMarathi ? 'वाहन तपशील' : 'Vehicle Details';

  // ---------------------------------------------------------------------------
  // VEHICLE EXIT & SETTLEMENT
  // ---------------------------------------------------------------------------
  static String get vehicleExit => _isMarathi ? 'वाहन निर्गमन' : 'Vehicle Exit';
  static String get vehicleExitTitle => _isMarathi ? 'वाहन निर्गमन' : 'Vehicle Exit';
  static String get scanQr => _isMarathi ? 'QR स्कॅन करा' : 'Scan QR';
  static String get scanQrButton => _isMarathi ? 'QR कोड स्कॅन करा' : 'Scan QR Code';
  static String get searchByVehicleOrTicket => _isMarathi ? 'तिकीट किंवा वाहन क्रमांक शोधा' : 'Search by Ticket or Vehicle Number';
  static String get searchTicketOrVehicle => _isMarathi ? 'तिकीट किंवा वाहन क्रमांक शोधा' : 'Search by Ticket or Vehicle Number';
  static String get searchExitSubtitle => _isMarathi ? 'सक्रिय वाहन शोधण्यासाठी तिकीट किंवा नंबर टाका' : 'Enter ticket or vehicle registration to locate active session';
  static String get searchActiveVehicle => _isMarathi ? 'सक्रिय वाहन शोधा' : 'Search Active Vehicle';
  static String get searchExitHint => _isMarathi ? 'तिकीट क्र. (उदा. 1013) किंवा वाहन क्र.' : 'Ticket No. (e.g. 1013) or Vehicle No.';
  static String get searchButton => _isMarathi ? 'शोधा' : 'Search';
  static String get vehicleAlreadyExited => _isMarathi ? 'हे वाहन आधीच बाहेर पडले आहे.' : 'This vehicle has already exited.';
  static String get vehicleNotParked => _isMarathi ? 'हे वाहन सध्या पार्किंगमध्ये नाही किंवा आधीच बाहेर पडले आहे.' : 'Vehicle is not currently parked or has already exited.';
  static String get ticketNotFound => _isMarathi ? 'तिकीट सापडले नाही.' : 'Ticket not found.';
  static String get multipleVehiclesFound => _isMarathi ? 'एकापेक्षा जास्त वाहने सापडली' : 'Multiple Vehicles Found';
  static String get selectVehicle => _isMarathi ? 'वाहन निवडा' : 'Select Vehicle';

  // Exit Verification & Charge Screen
  static String get exitVerificationTitle => _isMarathi ? 'वाहन पडताळणी' : 'Vehicle Verification';
  static String get verifyVehicleForExit => _isMarathi ? 'वाहन पडताळणी' : 'Vehicle Verification';
  static String get exitVerification => _isMarathi ? 'वाहन पडताळणी' : 'Vehicle Verification';
  static String get verifyVehicleNotice => _isMarathi
      ? 'कृपया वाहनाचा फोटो आणि क्रमांक तपासून निर्गमन निश्चित करा.'
      : 'Please verify the vehicle photo and number before confirming exit.';
  static String get confirmVehicle => _isMarathi ? 'वाहन निश्चित करा' : 'Confirm Vehicle';
  static String get cancelSearchAgain => _isMarathi ? 'रद्द करा व पुन्हा शोधा' : 'Cancel / Search Again';
  static String get exitChargeTitle => _isMarathi ? 'शुल्क आकारणी व निर्गमन' : 'Exit Fee Settlement';
  static String get exitFeeSettlement => _isMarathi ? 'शुल्क आकारणी व निर्गमन' : 'Exit Fee Settlement';
  static String get recalculate => _isMarathi ? 'पुन्हा गणना करा' : 'Recalculate';
  static String get photoPreviewUnavailable => _isMarathi ? 'फोटो पूर्वावलोकन उपलब्ध नाही' : 'Photo preview unavailable';
  static String get photoNoLongerAvailable => _isMarathi ? 'वाहनाचा फोटो यापुढे उपलब्ध नाही.' : 'Vehicle photo no longer available.';
  static String get vehicleExitedSuccessfully => _isMarathi ? 'वाहन निर्गमन यशस्वी झाले' : 'Vehicle Exited Successfully';
  static String get vehiclePhoto => _isMarathi ? 'वाहनाचा फोटो' : 'Vehicle Photo';
  static String get photoCleanup => _isMarathi ? 'फोटो स्वच्छता' : 'Photo Cleanup';
  static String get photoDeletedAfterExit => _isMarathi ? 'निर्गमनानंतर वाहनाचा फोटो आपोआप हटवला गेला.' : 'Vehicle photo automatically deleted upon exit.';
  static String get advanceShift => _isMarathi ? 'आगाऊ पाळी' : 'Advance Shift';
  static String get stayDurationAndCharges => _isMarathi ? 'पार्किंग कालावधी व शुल्क' : 'Stay Duration & Charges';
  static String get stayDuration => _isMarathi ? 'पार्किंग कालावधी' : 'Stay Duration';
  static String get stayDurationLabel => _isMarathi ? 'पार्किंग कालावधी' : 'Stay Duration';
  static String get exitTime => _isMarathi ? 'निर्गमन वेळ' : 'Exit Time';
  static String get billableHours => _isMarathi ? 'आकारणीयोग्य तास' : 'Billable Hours';
  static String get billableHoursLabel => _isMarathi ? 'आकारणीयोग्य तास' : 'Billable Hours';
  static String get hoursSuffix => _isMarathi ? 'तास' : 'hrs';
  static String get grossParkingCharge => _isMarathi ? 'एकूण पार्किंग शुल्क' : 'Gross Parking Charge';
  static String get grossChargeLabel => _isMarathi ? 'एकूण पार्किंग शुल्क' : 'Gross Parking Charge';
  static String get advanceAdjusted => _isMarathi ? 'आगाऊ वजावट' : 'Advance Adjusted';
  static String get advanceAdjustedLabel => _isMarathi ? 'आगाऊ वजावट' : 'Advance Adjusted';
  static String get balanceDue => _isMarathi ? 'बाकी रक्कम' : 'Final Balance Due';
  static String get balanceDueLabel => _isMarathi ? 'बाकी रक्कम' : 'Final Balance Due:';
  static String get finalBalancePaid => _isMarathi ? 'बाकी रक्कम भरली' : 'Final Balance Paid';
  static String get refund => _isMarathi ? 'परतावा' : 'Refund to Customer';
  static String get refundHandedBack => _isMarathi ? 'परतावा दिलेली रक्कम' : 'Refund Handed Back';
  static String get refundToCustomerLabel => _isMarathi ? 'ग्राहकाला परतावा:' : 'Refund to Customer:';
  static String get fullyCoveredSettled => _isMarathi ? 'पूर्ण भरणा झाला (बाकी ₹०)' : 'Fully Settled (₹0 Balance Due)';
  static String get fullySettledNotice => _isMarathi ? 'पूर्ण भरणा झाला (बाकी ₹०)' : 'Fully Settled (₹0 Balance Due)';
  static String get selectSettlementMode => _isMarathi ? 'पेमेंट पद्धत निवडा' : 'Select Payment Method';
  static String get cashReceived => _isMarathi ? 'रोख रक्कम मिळाली' : 'Cash Received';
  static String get changeToReturn => _isMarathi ? 'परत करायची बाकी' : 'Change to Return';
  static String get confirmUpiReceived => _isMarathi ? 'UPI पेमेंट मिळाल्याची पुष्टी' : 'Confirm UPI Received';
  static String get confirmUpiReceivedNotice => _isMarathi
      ? 'कृपया पुढे जाण्यापूर्वी UPI पेमेंट मिळाल्याची पुष्टी करा'
      : 'Please confirm UPI payment received before completing settlement';
  static String get confirmRefundHandedNotice => _isMarathi
      ? 'कृपया पुढे जाण्यापूर्वी ग्राहकाला परतावा दिल्याबद्दल पुष्टी करा'
      : 'Please confirm refund handed to customer before releasing slot';
  static String get finalSettlement => _isMarathi ? 'अंतिम भरणा' : 'Final Settlement';
  static String get paymentMethod => _isMarathi ? 'पेमेंट पद्धत' : 'Payment Method';
  static String get paymentReceivedConfirm => _isMarathi
      ? 'UPI पेमेंट मिळाल्याची खात्री केली आहे'
      : 'I confirm that UPI payment has been received';
  static String get refundHandedConfirm => _isMarathi
      ? 'परतावा रक्कम ग्राहकाला दिली आहे'
      : 'I confirm that refund has been handed to customer';
  static String get confirmRefundHanded => _isMarathi
      ? 'परतावा रक्कम ग्राहकाला दिली आहे याची खात्री करा'
      : 'I confirm that refund has been handed to customer';
  static String get collectBalanceAndExit => _isMarathi
      ? 'रक्कम जमा करून निर्गमन निश्चित करा'
      : 'Collect Balance & Confirm Exit';
  static String get refundAndExit => _isMarathi
      ? 'परतावा देऊन निर्गमन निश्चित करा'
      : 'Issue Refund & Confirm Exit';
  static String get confirmExitReleaseSlot => _isMarathi ? 'निर्गमन निश्चित करा व जागा मोकळी करा' : 'Confirm Exit & Release Slot';
  static String get handoverRefundComplete => _isMarathi ? 'परतावा देऊन निर्गमन पूर्ण करा' : 'Handover Refund & Complete Exit';
  static String get completeSettlementRelease => _isMarathi ? 'भरणा पूर्ण करा व जागा मोकळी करा' : 'Complete Settlement & Release Slot';
  static String get confirmExitButton => _isMarathi ? 'निर्गमन निश्चित करा' : 'Confirm Exit';
  static String get settlementInProgress => _isMarathi ? 'निर्गमन प्रक्रिया सुरू आहे...' : 'Processing exit settlement...';

  // Audit
  static String get noResponsibilityHistory => _isMarathi ? 'कोणतीही जबाबदारी नोंद आढळली नाही' : 'No responsibility events recorded';
  static String get crossShiftAudit => _isMarathi ? 'पाळीनिहाय सुरक्षा रक्षक नोंदी' : 'Cross-Shift Guard Audit';
  static String get entryGuard => _isMarathi ? 'प्रवेश रक्षक' : 'Entry Guard';
  static String get advanceCollector => _isMarathi ? 'आगाऊ जमा रक्षक' : 'Advance Collector';
  static String get exitGuard => _isMarathi ? 'निर्गमन रक्षक' : 'Exit Guard';
  static String get settledAndExited => _isMarathi ? 'निर्गमन पूर्ण झाले' : 'SETTLED & EXITED';

  // Exit Success & Receipt
  static String get vehicleExitSettledTitle => _isMarathi ? 'वाहन निर्गमन यशस्वी!' : 'Vehicle Exit Settled!';
  static String get vehicleExitSettledSubtitle => _isMarathi ? 'शुल्क आकारणी व निर्गमन पूर्ण झाले.' : 'Payment settlement complete and parking slot released.';
  static String get exitSuccessTitle => _isMarathi ? 'वाहन निर्गमन यशस्वी!' : 'Vehicle Exit Successful!';
  static String get exitReceiptTitle => _isMarathi ? 'निर्गमन पावती' : 'EXIT RECEIPT';
  static String get totalAmountLabel => _isMarathi ? 'एकूण रक्कम' : 'TOTAL AMOUNT';
  static String get refundHandedLabel => _isMarathi ? 'परतावा दिलेली रक्कम:' : 'REFUND HANDED BACK:';
  static String get refundMethodLabel => _isMarathi ? 'परतावा पद्धत:' : 'REFUND METHOD:';
  static String get printExitReceipt => _isMarathi ? 'निर्गमन पावती प्रिंट करा' : 'Print Exit Receipt';
  static String get viewFinalExitReceipt => _isMarathi ? 'अंतिम निर्गमन पावती पहा' : 'View Final Exit Receipt';
  static String get viewFinalReceipt => _isMarathi ? 'अंतिम निर्गमन पावती पहा' : 'View Final Exit Receipt';
  static String get thankYouVisitAgain => _isMarathi ? 'धन्यवाद! पुन्हा भेट द्या.' : 'Thank you! Visit again.';

  // ---------------------------------------------------------------------------
  // BLUETOOTH PRINTER & SETTINGS
  // ---------------------------------------------------------------------------
  static String get bluetoothPrinterTitle => _isMarathi ? 'ब्लूटूथ प्रिंटर (58mm)' : 'Bluetooth Thermal Printer';
  static String get printerStatusConnected => _isMarathi ? 'प्रिंटर जोडलेला आहे' : 'Connected';
  static String get printerStatusDisconnected => _isMarathi ? 'प्रिंटर जोडलेला नाही' : 'Disconnected';
  static String get scanForPrinters => _isMarathi ? 'प्रिंटर शोधा (Scan)' : 'Scan for Devices';
  static String get scanningPrinters => _isMarathi ? 'प्रिंटर शोधत आहे...' : 'Scanning for bluetooth printers...';
  static String get connectButton => _isMarathi ? 'जोडा (Connect)' : 'Connect';
  static String get disconnectButton => _isMarathi ? 'डिस्कनेक्ट करा' : 'Disconnect';
  static String get testPrintButton => _isMarathi ? 'टेस्ट प्रिंट करा' : 'Test Print';
  static String get noPrintersFound => _isMarathi ? 'कोणताही ब्लूटूथ प्रिंटर सापडला नाही' : 'No paired bluetooth printers found';
  static String get languageSettingsTitle => _isMarathi ? 'भाषा व सेटिंग्ज' : 'Language & Settings';
  static String get appUiLanguageSection => _isMarathi ? 'अ‍ॅपची मुख्य भाषा' : 'Application Language';
  static String get langEnglish => 'English';
  static String get langMarathi => 'मराठी (Marathi)';
  static String get businessProfileSection => _isMarathi ? 'पार्किंग व्यवसायाची माहिती' : 'Business Profile';
  static String get bizflowBrandingSwitch => _isMarathi
      ? 'पावतीवर BizFlow ब्रँडिंग दाखवा'
      : 'Show BizFlow Branding on Receipt';
  static String get settingsSavedNotice => _isMarathi ? 'सेटिंग्ज जतन केल्या आहेत.' : 'Settings saved successfully.';

  // ---------------------------------------------------------------------------
  // SHIFT MANAGEMENT & MY SHIFT (Admin Controlled 8-Hour Fixed System)
  // ---------------------------------------------------------------------------
  static String get shiftManagement => _isMarathi ? 'पाळी व्यवस्थापन' : 'Shift Management';
  static String get myShiftTitle => _isMarathi ? 'माझी पाळी' : 'My Shift';
  static String get assigned => _isMarathi ? 'नियुक्त' : 'Assigned';
  static String get activeState => _isMarathi ? 'सक्रिय' : 'Active';
  static String get completedState => _isMarathi ? 'पूर्ण झाले' : 'Completed';
  static String get cancelledState => _isMarathi ? 'रद्द केले' : 'Cancelled';
  static String get startTime => _isMarathi ? 'सुरू होण्याची वेळ' : 'Start Time';
  static String get endTime => _isMarathi ? 'समाप्ती वेळ' : 'End Time';
  static String get duration => _isMarathi ? 'कालावधी' : 'Duration';
  static String get eightHours => _isMarathi ? '८ तास' : '8 Hours';
  static String get fixed8Hours => _isMarathi ? '८ तास (निश्चित)' : '8 Hours (Fixed)';
  static String get noActiveShiftAssigned => _isMarathi
      ? 'तुम्हाला सध्या कोणतीही सक्रिय पाळी नियुक्त केलेली नाही.'
      : 'No active shift is assigned to you.';
  static String get contactAdmin => _isMarathi ? 'कृपया ॲडमिनशी संपर्क साधा.' : 'Please contact Admin.';
  static String get noActiveShiftWarning => _isMarathi
      ? 'सक्रिय पाळी नियुक्त नसल्यामुळे नवीन वाहन प्रवेश बंद आहे. कृपया ॲडमिनशी संपर्क साधा.'
      : 'No active shift is assigned to you. Vehicle entry is blocked. Please contact Admin.';
  static String get currentShift => _isMarathi ? 'चालू पाळी' : 'Current Shift';
  static String get viewMyShift => _isMarathi ? 'माझी पाळी पहा' : 'View My Shift';
  static String get timeElapsed => _isMarathi ? 'झालेला वेळ' : 'Time Elapsed';
  static String get timeRemaining => _isMarathi ? 'उर्वरित वेळ' : 'Time Remaining';
  static String get upcomingShifts => _isMarathi ? 'आगामी पाळ्या' : 'Upcoming Shifts';
  static String get shiftHistory => _isMarathi ? 'मागील पाळ्यांचा इतिहास' : 'Shift History';
  static String get noUpcomingShifts => _isMarathi ? 'कोणतीही आगामी पाळी नाही.' : 'No upcoming shifts assigned.';
  static String get noCompletedShifts => _isMarathi ? 'पूर्ण झालेल्या पाळ्यांचा इतिहास नाही.' : 'No completed shifts yet.';
  static String get assignShift => _isMarathi ? 'पाळी नियुक्त करा' : 'Assign Shift';
  static String get createShift => _isMarathi ? 'नवीन पाळी तयार करा' : 'Create Shift';
  static String get selectGuard => _isMarathi ? 'सुरक्षा रक्षक निवडा' : 'Select Guard';
  static String get selectDate => _isMarathi ? 'तारीख निवडा' : 'Select Date';
  static String get selectStartTime => _isMarathi ? 'सुरू होण्याची वेळ निवडा' : 'Select Start Time';
  static String get autoCalculatedEndTime => _isMarathi ? '८ तासांनुसार गणना केलेली समाप्ती वेळ' : '8-hour automatically calculated end time';
  static String get overlappingShiftError => _isMarathi
      ? 'या सुरक्षा रक्षकास आधीच या वेळेत दुसरी पाळी नियुक्त आहे.'
      : 'This guard already has an overlapping shift.';
  static String get shiftAssignedSuccess => _isMarathi ? 'पाळी यशस्वीरित्या नियुक्त करण्यात आली.' : 'Shift assigned successfully.';
  static String get shiftUpdatedSuccess => _isMarathi ? 'पाळी माहिती अपडेट करण्यात आली.' : 'Shift updated successfully.';
  static String get shiftCancelledSuccess => _isMarathi ? 'पाळी रद्द करण्यात आली.' : 'Shift cancelled successfully.';
  static String get editShift => _isMarathi ? 'पाळी संपादित करा' : 'Edit Shift';
  static String get cancelShift => _isMarathi ? 'पाळी रद्द करा' : 'Cancel Shift';
  static String get shiftDate => _isMarathi ? 'पाळी तारीख' : 'Shift Date';
  static String get collection => _isMarathi ? 'संकलन' : 'Collection';
  static String get todaysShifts => _isMarathi ? 'आजच्या पाळ्या' : "Today's Shifts";
  static String get activeShifts => _isMarathi ? 'सक्रिय पाळ्या' : 'Active Shifts';
  static String get allShifts => _isMarathi ? 'सर्व पाळ्या' : 'All Shifts';
  static String get filterShifts => _isMarathi ? 'फिल्टर' : 'Filter';
  static String get shiftOfficer => _isMarathi ? 'रक्षक:' : 'Officer:';
  static String get activeShift => _isMarathi ? 'सध्याची पाळी:' : 'Active Shift:';
  static String get shiftStartedAt => _isMarathi ? 'पाळी सुरू झाली:' : 'Shift Started:';

  // ---------------------------------------------------------------------------
  // PAYMENT MANAGEMENT & SHIFT VERIFICATION
  // ---------------------------------------------------------------------------
  static String get paymentManagement => _isMarathi ? 'पेमेंट व्यवस्थापन' : 'Payment Management';
  static String get overview => _isMarathi ? 'आढावा' : 'Overview';
  static String get keepWithMe => _isMarathi ? 'स्वतःकडे शिल्लक' : 'Keep With Me';
  static String get handovers => _isMarathi ? 'हस्तांतरण' : 'Handovers';
  static String get withdrawals => _isMarathi ? 'पैसे काढणे' : 'Withdrawals';
  static String get guardAndShiftReports => _isMarathi ? 'रक्षक व पाळी अहवाल' : 'Guard & Shift Reports';
  static String get guardWiseSummary => _isMarathi ? 'रक्षकनिहाय सारांश' : 'Guard-Wise Summary';
  static String get shiftWiseSummary => _isMarathi ? 'पाळीनिहाय सारांश' : 'Shift-Wise Summary';
  static String get totalCollection => _isMarathi ? 'एकूण संकलन' : 'Total Collection';
  static String get todayTotalCollection => _isMarathi ? 'आजचे एकूण संकलन' : "Today's Total Collection";
  static String get cashCollection => _isMarathi ? 'रोख संकलन' : 'Cash Collection';
  static String get upiCollection => _isMarathi ? 'UPI संकलन' : 'UPI Collection';
  static String get expectedCash => _isMarathi ? 'अपेक्षित रोख' : 'Expected Cash';
  static String get collectedCash => _isMarathi ? 'संकलित रोख' : 'Collected Cash';
  static String get expectedUpi => _isMarathi ? 'अपेक्षित UPI' : 'Expected UPI';
  static String get collectedUpi => _isMarathi ? 'संकलित UPI' : 'Collected UPI';
  static String get numberOfCashTransactions => _isMarathi ? 'रोख व्यवहारांची संख्या' : 'Number of Cash Transactions';
  static String get numberOfUpiTransactions => _isMarathi ? 'UPI व्यवहारांची संख्या' : 'Number of UPI Transactions';
  static String get transactions => _isMarathi ? 'व्यवहार' : 'Transactions';
  static String get viewTransactions => _isMarathi ? 'व्यवहार पहा' : 'View Transactions';
  static String get noPaymentTransactionsToday => _isMarathi ? 'आज कोणतेही पेमेंट व्यवहार नाहीत.' : 'No payment transactions today.';
  static String get unableToLoadPaymentReport => _isMarathi ? 'पेमेंट अहवाल लोड करता आला नाही. कृपया पुन्हा प्रयत्न करा.' : 'Unable to load payment report. Please try again.';
  static String get retry => _isMarathi ? 'पुन्हा प्रयत्न करा' : 'Retry';
  static String get tryAgain => _isMarathi ? 'पुन्हा प्रयत्न करा' : 'Try Again';
  static String get transactionType => _isMarathi ? 'व्यवहार प्रकार' : 'Transaction Type';
  static String get amount => _isMarathi ? 'रक्कम' : 'Amount';
  static String get ticketNumberLabel => _isMarathi ? 'तिकीट क्रमांक' : 'Ticket Number';
  static String get vehicleNumberText => _isMarathi ? 'वाहन क्रमांक' : 'Vehicle Number';
  static String get date => _isMarathi ? 'दिनांक' : 'Date';
  static String get time => _isMarathi ? 'वेळ' : 'Time';
  static String get advance => _isMarathi ? 'अ‍ॅडव्हान्स' : 'Advance';
  static String get finalPayment => _isMarathi ? 'अंतिम' : 'Final';
  static String get refunds => _isMarathi ? 'परतावे' : 'Refunds';
  static String get all => _isMarathi ? 'सर्व' : 'All';
  static String get verifyingActiveShift => _isMarathi ? 'पाळी पडताळणी सुरू आहे...' : 'Verifying active shift...';
  static String get unableToVerifyShift => _isMarathi ? 'पाळी पडताळणी अयशस्वी. कृपया पुन्हा प्रयत्न करा.' : 'Unable to verify shift. Please retry.';
  static String get loadingShiftInfo => _isMarathi ? 'पाळी माहिती लोड होत आहे...' : 'Loading shift information...';
  static String get unableToLoadShiftDetails => _isMarathi ? 'पाळी माहिती लोड करता आली नाही.' : 'Unable to load shift information.';
  static String get noShiftAssigned => _isMarathi ? 'कोणतीही पाळी नियुक्त केलेली नाही.' : 'No shift assigned.';
  static String get startsIn => _isMarathi ? 'सुरू होण्यास वेळ:' : 'Starts in:';
  static String get upcomingAssignedShift => _isMarathi ? 'आगामी नियुक्त पाळी' : 'Upcoming Assigned Shift';
  static String get outstandingCash => _isMarathi ? 'शिल्लक रोख' : 'Outstanding Cash';
  static String get outstandingUpi => _isMarathi ? 'शिल्लक UPI' : 'Outstanding UPI';
  static String get totalCollected => _isMarathi ? 'एकूण संकलित' : 'Total Collected';
  static String get handedOver => _isMarathi ? 'हस्तांतरित' : 'Handed Over';
  static String get withdrawn => _isMarathi ? 'काढलेली रक्कम' : 'Withdrawn';
  static String get received => _isMarathi ? 'प्राप्त' : 'Received';
  static String get settled => _isMarathi ? 'सेटल झाले' : 'Settled';
  static String get withdraw => _isMarathi ? 'काढून घ्या' : 'Withdraw';
  static String get handover => _isMarathi ? 'हस्तांतरण' : 'Handover';
  static String get newestActivity => _isMarathi ? 'नवीनतम हालचाल' : 'Newest Activity';
  static String get oldestActivity => _isMarathi ? 'जुनी हालचाल' : 'Oldest Activity';
  static String get withdrawFullCash => _isMarathi ? 'सर्व रोख काढा' : 'Withdraw Full Cash';
  static String get withdrawFullUpi => _isMarathi ? 'सर्व UPI काढा' : 'Withdraw Full UPI';
  static String get withdrawCash => _isMarathi ? 'रोख काढा' : 'Withdraw Cash';
  static String get withdrawUpi => _isMarathi ? 'UPI काढा' : 'Withdraw UPI';
  static String get currentCashOutstanding => _isMarathi ? 'सध्याची थकीत रोख' : 'Current Cash Outstanding';
  static String get currentUpiOutstanding => _isMarathi ? 'सध्याची थकीत UPI' : 'Current UPI Outstanding';
  static String get withdrawalAmount => _isMarathi ? 'काढण्याची रक्कम' : 'Withdrawal Amount';
  static String get remainingAfterWithdrawal => _isMarathi ? 'काढल्यानंतर शिल्लक' : 'Remaining After Withdrawal';
  static String get confirmCashWithdrawal => _isMarathi ? 'रोख काढण्याची पुष्टी करा' : 'Confirm Cash Withdrawal';
  static String get confirmUpiWithdrawal => _isMarathi ? 'UPI काढण्याची पुष्टी करा' : 'Confirm UPI Withdrawal';
  static String get confirmWithdrawal => _isMarathi ? 'पैसे काढण्याची पुष्टी करा' : 'Confirm Withdrawal';
  static String get previousOutstanding => _isMarathi ? 'मागील थकीत' : 'Previous Outstanding';
  static String get remainingOutstanding => _isMarathi ? 'शिल्लक थकीत' : 'Remaining Outstanding';
  static String get withdrawalMustBeGreaterThanZero => _isMarathi ? 'काढण्याची रक्कम ₹० पेक्षा जास्त असावी.' : 'Withdrawal amount must be greater than ₹0.';
  static String get pleaseEnterValidAmount => _isMarathi ? 'कृपया वैध रक्कम टाका.' : 'Please enter a valid amount.';
  static String get withdrawalSuccess => _isMarathi ? 'पैसे काढणे यशस्वी झाले.' : 'Withdrawal successful.';
  static String get withdrawalFailed => _isMarathi ? 'पैसे काढणे अयशस्वी झाले. कृपया पुन्हा प्रयत्न करा.' : 'Withdrawal failed. Please try again.';
  static String withdrawalAmountExceeds(String method, String amount) =>
      _isMarathi ? 'काढण्याची रक्कम $amount च्या सध्याच्या थकीत $method पेक्षा जास्त असू शकत नाही.' : 'Withdrawal amount cannot exceed current ${method.toLowerCase()} outstanding of $amount.';
  static String get allTime => _isMarathi ? 'सर्व वेळ' : 'All Time';
  static String get allStatus => _isMarathi ? 'सर्व स्थिती' : 'All Status';
  static String get allMethods => _isMarathi ? 'सर्व पद्धती' : 'All Methods';
  static String get carriedForward => _isMarathi ? 'पुढे नेण्यात आले' : 'Carried Forward';
  static String get recorded => _isMarathi ? 'नोंदवले' : 'Recorded';
  static String get notes => _isMarathi ? 'टीप' : 'Notes';
  static String get from => _isMarathi ? 'कडून' : 'From';
  static String get to => _isMarathi ? 'कडे' : 'To';
  static String get fromGuard => _isMarathi ? 'कडून रक्षक' : 'From Guard';
  static String get toGuard => _isMarathi ? 'कडे रक्षक' : 'To Guard';
  static String get fromShift => _isMarathi ? 'सुरू पाळी' : 'From Shift';
  static String get toShift => _isMarathi ? 'पुढील पाळी' : 'To Shift';
  static String get created => _isMarathi ? 'तयार केले' : 'Created';
  static String get accepted => _isMarathi ? 'स्वीकारले' : 'Accepted';
  static String get rejected => _isMarathi ? 'नाकारले' : 'Rejected';
  static String get cancelled => _isMarathi ? 'रद्द केले' : 'Cancelled';
  static String get pending => _isMarathi ? 'प्रलंबित' : 'Pending';
  static String get completed => _isMarathi ? 'पूर्ण' : 'Completed';
  static String get upcoming => _isMarathi ? 'आगामी' : 'Upcoming';
  static String get timestamp => _isMarathi ? 'वेळ नोंद' : 'Timestamp';
  static String get withdrawnBy => _isMarathi ? 'काढणारा ॲडमिन' : 'Withdrawn by';
  static String get noKeepWithMeHistory => _isMarathi ? 'कोणताही स्वतःकडील शिल्लक इतिहास नाही.' : 'No Keep With Me history yet.';
  static String get noHandoverHistory => _isMarathi ? 'कोणताही हस्तांतरण इतिहास नाही.' : 'No handover history yet.';
  static String get noWithdrawalHistory => _isMarathi ? 'कोणताही पैसे काढण्याचा रेकॉर्ड नाही.' : 'No admin withdrawal records found.';
  static String get searchTransactionsHint => _isMarathi ? 'वाहन, तिकीट, रक्षक, व्यवहार ID शोधा...' : 'Search Vehicle, Ticket, Guard, Txn ID...';
  static String get searchGuardsUidShiftHint => _isMarathi ? 'रक्षकाचे नाव, UID, पाळी शोधा...' : 'Search Guard Name, UID, Shift...';
  static String get searchKeepWithMeHint => _isMarathi ? 'रक्षक, पाळी, टीप शोधा...' : 'Search Guard, Shift, Notes...';
  static String get searchHandoversHint => _isMarathi ? 'रक्षक, हस्तांतरण ID, पाळी शोधा...' : 'Search Guard, Handover ID, Shift...';
  static String get searchWithdrawalsHint => _isMarathi ? 'रक्षक, ॲडमिन, ID, पाळी शोधा...' : 'Search Guard, Admin, ID, Shift...';

  // Helper formatters
  static String formatStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return _isMarathi ? 'सक्रिय' : 'Active';
      case 'PENDING':
        return _isMarathi ? 'प्रलंबित' : 'Pending';
      case 'ACCEPTED':
        return _isMarathi ? 'स्वीकारले' : 'Accepted';
      case 'REJECTED':
        return _isMarathi ? 'नाकारले' : 'Rejected';
      case 'CANCELLED':
        return _isMarathi ? 'रद्द केले' : 'Cancelled';
      case 'COMPLETED':
        return _isMarathi ? 'पूर्ण' : 'Completed';
      case 'ASSIGNED':
        return _isMarathi ? 'नियुक्त' : 'Assigned';
      case 'UPCOMING':
        return _isMarathi ? 'आगामी' : 'Upcoming';
      default:
        return status;
    }
  }

  static String formatPaymentType(String type) {
    switch (type.toUpperCase()) {
      case 'ADVANCE':
        return _isMarathi ? 'अ‍ॅडव्हान्स' : 'Advance';
      case 'FINAL':
        return _isMarathi ? 'अंतिम' : 'Final';
      case 'REFUND':
        return _isMarathi ? 'परतावा' : 'Refund';
      default:
        return type;
    }
  }

  static String formatPaymentMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return _isMarathi ? 'रोख' : 'Cash';
      case 'UPI':
        return 'UPI';
      default:
        return method;
    }
  }

  // Reports Hub & Guard Financial Report
  static String get parkingSummary => _isMarathi ? 'वाहनतळ सारांश' : 'Parking Summary';
  static String get totalEntries => _isMarathi ? 'एकूण प्रवेश' : 'Total Entries';
  static String get totalExits => _isMarathi ? 'एकूण निर्गमन' : 'Total Exits';
  static String get currentlyParked => _isMarathi ? 'सध्या पार्क केलेली वाहने' : 'Currently Parked';
  static String get vehicleReport => _isMarathi ? 'वाहन अहवाल' : 'Vehicle Report';
  static String get searchVehicleTicketGuardHint => _isMarathi ? 'वाहन / तिकीट / रक्षक शोधा...' : 'Search Vehicle / Ticket / Guard...';
  static String get typeAll => _isMarathi ? 'प्रकार: सर्व' : 'Type: All';
  static String get statusAll => _isMarathi ? 'स्थिती: सर्व' : 'Status: All';
  static String get sortNewest => _isMarathi ? 'क्रम: नवीनतम' : 'Sort: Newest';
  static String get sortOldest => _isMarathi ? 'क्रम: जुने' : 'Sort: Oldest';
  static String get parkedLive => _isMarathi ? 'पार्क केलेले / थेट' : 'Parked / Live';
  static String get noVehiclesFound => _isMarathi ? 'या कालावधीसाठी कोणतीही वाहने सापडली नाहीत.' : 'No vehicles found for this period.';
  static String get entryDateTime => _isMarathi ? 'प्रवेश दिनांक व वेळ' : 'Entry Date & Time';
  static String get exitDateTime => _isMarathi ? 'निर्गमन दिनांक व वेळ' : 'Exit Date & Time';
  static String get collectionSummary => _isMarathi ? 'संकलन सारांश' : 'Collection Summary';
  static String get currentOutstanding => _isMarathi ? 'चालू शिल्लक' : 'Current Outstanding';
  static String get activity => _isMarathi ? 'हालचाली' : 'Activity';
  static String get responsibilityHistory => _isMarathi ? 'जबाबदारी इतिहास' : 'Responsibility History';
  static String get dateWiseSummary => _isMarathi ? 'दिनांकनिहाय सारांश' : 'Date-wise Summary';
  static String get outstandingExplanation => _isMarathi ? 'शिल्लक = या रक्षकाच्या जबाबदारीखाली सध्या शिल्लक असलेली रक्कम.' : "Outstanding = amount currently remaining under this Guard's responsibility.";
  static String get searchActivityHint => _isMarathi ? 'तिकीट, वाहन, रक्कम...' : 'Ticket, vehicle, amount...';
  static String get noActivityFound => _isMarathi ? 'या कालावधीसाठी कोणतीही हालचाल सापडली नाही.' : 'No activity found for this period.';
  static String get details => _isMarathi ? 'तपशील' : 'Details';
  static String get period => _isMarathi ? 'कालावधी' : 'Period';
  static String get hours => _isMarathi ? 'तास' : 'Hours';
  static String get hours8 => _isMarathi ? '८ तास' : '8 Hours';
  static String get hours10 => _isMarathi ? '१० तास' : '10 Hours';
  static String get hours12 => _isMarathi ? '१२ तास' : '12 Hours';
  static String get hours24 => _isMarathi ? '२४ तास' : '24 Hours';

  static String formatShiftDuration(int hours) {
    if (_isMarathi) {
      const marathiDigits = {
        '0': '०', '1': '१', '2': '२', '3': '३', '4': '४',
        '5': '५', '6': '६', '7': '७', '8': '८', '9': '९',
      };
      final hoursStr = hours.toString().split('').map((c) => marathiDigits[c] ?? c).join('');
      return '$hoursStr तास';
    }
    return '$hours Hours';
  }
  static String get durationLongestFirst => _isMarathi ? 'कालावधी (दीर्घकाळ प्रथम)' : 'Duration (Longest First)';
  static String get noShiftsToday => _isMarathi ? 'आज कोणतीही पाळी नियोजित नाही.' : 'No shifts scheduled for today.';
  static String get noActiveShifts => _isMarathi ? 'या क्षणी कोणतीही सक्रिय पाळी नाही.' : 'No active shifts at this moment.';
  static String get noShiftRecordsFound => _isMarathi ? 'कोणतेही पाळी रेकॉर्ड सापडले नाहीत.' : 'No shift records found.';
  static String get totalCalculatedCapacity => _isMarathi ? 'एकूण गणना केलेली क्षमता' : 'Total Calculated Capacity';
  static String get slots => _isMarathi ? 'जागा' : 'slots';


  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------
  static String get notifications => _isMarathi ? 'सूचना' : 'Notifications';
  static String get noNotifications => _isMarathi ? 'कोणतीही सूचना नाही' : 'No Notifications';
  static String get noNotificationsDesc => _isMarathi
      ? 'नवीन सूचना किंवा पाळीचे अपडेट्स आल्यावर येथे दिसतील.'
      : 'New alerts, shift assignments, and updates will appear here.';
  static String get markAllAsRead => _isMarathi ? 'सर्व वाचले म्हणून चिन्हांकित करा' : 'Mark All as Read';
  static String get markAsRead => _isMarathi ? 'वाचले म्हणून खूण करा' : 'Mark Read';
  static String get unread => _isMarathi ? 'न वाचलेले' : 'Unread';
  static String get read => _isMarathi ? 'वाचलेले' : 'Read';
  static String get searchNotifications => _isMarathi ? 'सूचना शोधा...' : 'Search notifications...';
  static String get withdrawal => _isMarathi ? 'काढणे' : 'Withdrawal';
  static String get security => _isMarathi ? 'सुरक्षा' : 'Security';
  static String get systemCategory => _isMarathi ? 'सिस्टम' : 'System';

  // ---------------------------------------------------------------------------
  // ADMIN PORTAL & DASHBOARD
  // ---------------------------------------------------------------------------
  static String get adminPortalTitle => _isMarathi ? 'ॲडमिन व्यवस्थापन पोर्टल' : 'Admin Management Portal';
  static String get adminDashboard => _isMarathi ? 'ॲडमिन डॅशबोर्ड' : 'Admin Dashboard';
  static String get guardManagement => _isMarathi ? 'सुरक्षा रक्षक व्यवस्थापन' : 'Guard Management';
  static String get guards => _isMarathi ? 'सुरक्षा रक्षक' : 'Guards';
  static String get totalGuards => _isMarathi ? 'एकूण रक्षक' : 'Total Guards';
  static String get activeGuards => _isMarathi ? 'सक्रिय रक्षक' : 'Active Guards';
  static String get inactiveGuards => _isMarathi ? 'निष्क्रिय रक्षक' : 'Inactive Guards';
  static String get currentlyOnShift => _isMarathi ? 'सध्या ड्यूटीवर' : 'Currently On Shift';
  static String get guardsWithNoShift => _isMarathi ? 'पाळी नसलेले रक्षक' : 'Guards With No Shift';
  static String get parkingStatistics => _isMarathi ? 'वाहनतळ आकडेवारी' : 'Parking Statistics';
  static String get guardStatistics => _isMarathi ? 'रक्षक आकडेवारी' : 'Guard Statistics';
  static String get todaysOperations => _isMarathi ? 'आजची कामे व संकलन' : "Today's Operations";
  static String get addGuard => _isMarathi ? 'नवीन रक्षक जोडा' : 'Add Guard';
  static String get edit => _isMarathi ? 'संपादित करा' : 'Edit';
  static String get editGuard => _isMarathi ? 'रक्षक माहिती संपादित करा' : 'Edit Guard';
  static String get profileUpdatedSuccess => _isMarathi ? 'माहिती यशस्वीरित्या अद्यतनित केली.' : 'Profile updated successfully.';
  static String get activateGuard => _isMarathi ? 'रक्षक सक्रिय करा' : 'Activate Guard';
  static String get deactivateGuard => _isMarathi ? 'रक्षक निष्क्रिय करा' : 'Deactivate Guard';
  static String get guardActivatedSuccess => _isMarathi ? 'रक्षक यशस्वीरित्या सक्रिय केला.' : 'Guard activated successfully.';
  static String get guardDeactivatedSuccess => _isMarathi ? 'रक्षक निष्क्रिय केला.' : 'Guard deactivated.';
  static String get guardCreatedSuccess => _isMarathi ? 'नवीन रक्षक यशस्वीरित्या नोंदवला.' : 'Guard registered successfully.';
  static String get guardDetails => _isMarathi ? 'रक्षक तपशील' : 'Guard Details';
  static String get guardName => _isMarathi ? 'रक्षकाचे नाव' : 'Guard Name';
  static String get guardEmail => _isMarathi ? 'रक्षकाचा ईमेल' : 'Guard Email';
  static String get guardMobile => _isMarathi ? 'रक्षकाचा मोबाइल' : 'Guard Mobile';
  static String get guardStatus => _isMarathi ? 'रक्षक स्थिती' : 'Guard Status';
  static String get searchGuardsHint => _isMarathi ? 'नाव, ईमेल किंवा मोबाइलने शोधा...' : 'Search by name, email, or mobile...';
  static String get noGuardsFound => _isMarathi ? 'कोणताही रक्षक सापडला नाही.' : 'No guards found.';
  static String get confirmDeactivateGuard => _isMarathi ? 'रक्षक निष्क्रिय करण्याची पुष्टी करा' : 'Confirm Deactivate Guard';
  static String get confirmDeactivateGuardMsg => _isMarathi
      ? 'तुम्हाला खात्री आहे की तुम्ही या रक्षकास निष्क्रिय करू इच्छिता? त्यांचे ऐतिहासिक रेकॉर्ड सुरक्षित राहतील.'
      : 'Are you sure you want to deactivate this guard? Historical parking and payment records will be preserved.';
  static String get confirmActivateGuard => _isMarathi ? 'रक्षक सक्रिय करण्याची पुष्टी करा' : 'Confirm Activate Guard';
  static String get confirmActivateGuardMsg => _isMarathi
      ? 'तुम्हाला खात्री आहे की तुम्ही या रक्षकास पुन्हा सक्रिय करू इच्छिता?'
      : 'Are you sure you want to activate this guard?';
  static String get accountInactive => _isMarathi
      ? 'तुमचे खाते निष्क्रिय आहे. कृपया ॲडमिनशी संपर्क साधा.'
      : 'Your account is inactive. Please contact Admin.';
  static String get deactivateGuardTitle => _isMarathi ? 'रक्षक निष्क्रिय करायचा?' : 'Deactivate Guard?';
  static String get activateGuardTitle => _isMarathi ? 'रक्षक सक्रिय करायचा?' : 'Activate Guard?';
  static String get deactivateActiveShiftWarning => _isMarathi
      ? 'या रक्षकाची सध्या एक पाळी सुरू आहे.'
      : 'This Guard currently has an active shift.';
  static String get deactivateSuccess => _isMarathi ? 'रक्षक यशस्वीरित्या निष्क्रिय केला.' : 'Guard deactivated successfully.';
  static String get activateSuccess => _isMarathi ? 'रक्षक यशस्वीरित्या सक्रिय केला.' : 'Guard activated successfully.';
  static String get deactivateError => _isMarathi ? 'रक्षक निष्क्रिय करणे अयशस्वी झाले. कृपया पुन्हा प्रयत्न करा.' : 'Unable to deactivate Guard. Please try again.';
  static String get activateError => _isMarathi ? 'रक्षक सक्रिय करणे अयशस्वी झाले. कृपया पुन्हा प्रयत्न करा.' : 'Unable to activate Guard. Please try again.';
  static String get startShiftError => _isMarathi ? 'पाळी सुरू करणे अयशस्वी झाले. कृपया पुन्हा प्रयत्न करा.' : 'Unable to start this shift. Please try again.';
  static String get endShiftError => _isMarathi ? 'पाळी समाप्त करणे अयशस्वी झाले. कृपया पुन्हा प्रयत्न करा.' : 'Unable to end this shift. Please try again.';

  // ADMIN PAYMENT & REPORTS
  static String get transactionsLedger => _isMarathi ? 'व्यवहार लेजर' : 'Transactions Ledger';
  static String get guardWiseCollection => _isMarathi ? 'रक्षकनिहाय संकलन' : 'Guard-wise Collection';
  static String get shiftWiseCollection => _isMarathi ? 'पाळीनिहाय संकलन' : 'Shift-wise Collection';
  static String get netTotal => _isMarathi ? 'निव्वळ एकूण' : 'Net Total';
  static String get noTransactionsFound => _isMarathi ? 'कोणताही व्यवहार सापडला नाही.' : 'No transactions found.';
  static String get reports => _isMarathi ? 'अहवाल' : 'Reports';
  static String get reportsHub => _isMarathi ? 'अहवाल केंद्र' : 'Reports Hub';
  static String get dailyParkingReport => _isMarathi ? 'दैनिक वाहनतळ अहवाल' : 'Daily Parking Report';
  static String get dailyCollectionReport => _isMarathi ? 'दैनिक संकलन अहवाल' : 'Daily Collection Report';
  static String get cashReport => _isMarathi ? 'रोख संकलन अहवाल' : 'Cash Report';
  static String get upiReport => _isMarathi ? 'UPI संकलन अहवाल' : 'UPI Report';
  static String get guardWiseReport => _isMarathi ? 'रक्षकनिहाय अहवाल' : 'Guard-wise Report';
  static String get vehicleEntries => _isMarathi ? 'वाहन प्रवेश' : 'Vehicle Entries';
  static String get vehicleExits => _isMarathi ? 'वाहन निर्गमन' : 'Vehicle Exits';
  static String get noActiveGuard => _isMarathi ? 'कोणताही सक्रिय रक्षक नाही' : 'No Active Guard';
  static String get noGuardActiveShift => _isMarathi ? 'सध्या कोणत्याही रक्षकाची सक्रिय पाळी नाही.' : 'No Guard is currently on an active shift.';
  static String get multipleActiveShiftsWarning => _isMarathi ? 'एकापेक्षा जास्त सक्रिय पाळ्या आढळल्या. कृपया पाळी व्यवस्थापन तपासा.' : 'Multiple active shifts detected. Please check Shift Management.';
  static String get shiftWiseReport => _isMarathi ? 'पाळीनिहाय अहवाल' : 'Shift-wise Report';
  static String get vehicleEntryExitReport => _isMarathi ? 'वाहन प्रवेश/निर्गमन अहवाल' : 'Vehicle Entry/Exit Report';
  static String get adminSettings => _isMarathi ? 'ॲडमिन सेटिंग्ज' : 'Admin Settings';
  static String get rateChart => _isMarathi ? 'दर पत्रक' : 'Rate Chart';
  static String get capacitySettings => _isMarathi ? 'क्षमता सेटिंग्ज' : 'Capacity Settings';
  static String get fourWheelerCapacity => _isMarathi ? 'चारचाकी क्षमता' : 'Four-Wheeler Capacity';
  static String get twoWheelerCapacity => _isMarathi ? 'दुचाकी क्षमता' : 'Two-Wheeler Capacity';
  static String get totalParkingCapacity => _isMarathi ? 'एकूण पार्किंग क्षमता' : 'Total Parking Capacity';
  static String get shiftSettings => _isMarathi ? 'पाळी सेटिंग्ज' : 'Shift Settings';
  static String get shiftConfiguration => _isMarathi ? 'पाळी कॉन्फिगरेशन' : 'Shift Configuration';
  static String get allowedShiftDurations => _isMarathi ? 'मान्य पाळी कालावधी' : 'Allowed Shift Durations';
  static String get defaultShiftDuration => _isMarathi ? 'डीफॉल्ट पाळी कालावधी' : 'Default Shift Duration';
  static String get paymentOperations => _isMarathi ? 'पेमेंट ऑपरेशन्स' : 'Payment Operations';
  static String get cashCollectionEnabled => _isMarathi ? 'रोख संकलन सक्षम' : 'Cash Collection Enabled';
  static String get upiCollectionEnabled => _isMarathi ? 'UPI संकलन सक्षम' : 'UPI Collection Enabled';
  static String get advanceFeeEnabled => _isMarathi ? 'अ‍ॅडव्हान्स शुल्क सक्षम' : 'Advance Fee Enabled';
  static String get singleActiveDeviceMode => _isMarathi ? 'सिंगल अ‍ॅक्टिव्ह डिव्हाइस मोड' : 'Single Active Device Mode';
  static String get singleActiveDeviceSubtitle => _isMarathi
      ? 'सक्रिय असताना, फक्त एकाच डिव्हाइसवरून पार्किंगचे काम करता येईल.'
      : 'When enabled, only one operational device is allowed at a time for active parking operations.';
  static String get enabled => _isMarathi ? 'सक्षम' : 'Enabled';
  static String get disabled => _isMarathi ? 'अक्षम' : 'Disabled';
  static String get adminLogin => _isMarathi ? 'ॲडमिन लॉगिन' : 'Admin Login';
  static String get adminSignInSubtitle => _isMarathi
      ? 'व्यवस्थापन पॅनेलमध्ये प्रवेश करण्यासाठी लॉगिन करा'
      : 'Sign in to access the Admin Management Panel';
  static String get unauthorizedAdminAccess => _isMarathi
      ? 'तुम्हाला ॲडमिन पॅनेलमध्ये प्रवेश करण्याची परवानगी नाही.'
      : 'You are not authorized to access the Admin Panel.';
  static String get unauthorizedGuardAccess => _isMarathi
      ? 'हे खाते ॲडमिन आहे. कृपया ॲडमिन पोर्टल वापरा.'
      : 'This is an Admin account. Please use the Admin Portal.';
  static String get switchToAdmin => _isMarathi ? 'ॲडमिन पोर्टल' : 'Admin Portal';
  static String get switchToGuard => _isMarathi ? 'रक्षक पोर्टल' : 'Guard Portal';
  static String get switchToAdminPrompt => _isMarathi ? 'सिस्टम ॲडमिन? ॲडमिन लॉगिन करा' : 'System Admin? Switch to Admin Login';
  static String get switchToGuardPrompt => _isMarathi ? 'सुरक्षा रक्षक? रक्षक लॉगिन करा' : 'Duty Guard? Switch to Guard Login';
  static String get adminSignOutConfirmMessage => _isMarathi
      ? 'तुम्हाला खात्री आहे की तुम्ही ॲडमिन पॅनेलमधून बाहेर पडू इच्छिता?'
      : 'Are you sure you want to sign out of the Admin Panel?';

  // ---------------------------------------------------------------------------
  // SEARCH, FILTER & SORTING
  // ---------------------------------------------------------------------------
  static String get sortBy => _isMarathi ? 'क्रमवारी लावा' : 'Sort by';
  static String get filterBy => _isMarathi ? 'फिल्टर' : 'Filter';
  static String get newestFirst => _isMarathi ? 'नवीनतम प्रथम' : 'Newest First';
  static String get oldestFirst => _isMarathi ? 'सर्वात जुने प्रथम' : 'Oldest First';
  static String get longestParked => _isMarathi ? 'दीर्घकाळ पार्क केलेले' : 'Longest Parked';
  static String get shortestParked => _isMarathi ? 'कमी वेळ पार्क केलेले' : 'Shortest Parked';
  static String get vehicleAZ => _isMarathi ? 'वाहन क्रमांक (A-Z)' : 'Vehicle Number (A-Z)';
  static String get vehicleZA => _isMarathi ? 'वाहन क्रमांक (Z-A)' : 'Vehicle Number (Z-A)';
  static String get highestCurrentFee => _isMarathi ? 'सर्वाधिक चालू शुल्क' : 'Highest Current Fee';
  static String get lowestCurrentFee => _isMarathi ? 'किमान चालू शुल्क' : 'Lowest Current Fee';
  static String get highestAmount => _isMarathi ? 'सर्वाधिक रक्कम' : 'Highest Amount';
  static String get lowestAmount => _isMarathi ? 'किमान रक्कम' : 'Lowest Amount';
  static String get nameAZ => _isMarathi ? 'नाव (A-Z)' : 'Name (A-Z)';
  static String get nameZA => _isMarathi ? 'नाव (Z-A)' : 'Name (Z-A)';
  static String get newestCreated => _isMarathi ? 'नवीन तयार केलेले' : 'Newest Created';
  static String get oldestCreated => _isMarathi ? 'जुने तयार केलेले' : 'Oldest Created';
  static String get activeFirst => _isMarathi ? 'सक्रिय प्रथम' : 'Active First';
  static String get inactiveFirst => _isMarathi ? 'निष्क्रिय प्रथम' : 'Inactive First';
  static String get highestOutstanding => _isMarathi ? 'सर्वाधिक थकबाकी' : 'Highest Outstanding';
  static String get lowestOutstanding => _isMarathi ? 'किमान थकबाकी' : 'Lowest Outstanding';
  static String get startTimeNewest => _isMarathi ? 'सुरुवात वेळ (नवीनतम)' : 'Start Time (Newest)';
  static String get startTimeOldest => _isMarathi ? 'सुरुवात वेळ (जुनी)' : 'Start Time (Oldest)';
  static String get endTimeSort => _isMarathi ? 'समाप्ती वेळ' : 'End Time';
  static String get guardAZ => _isMarathi ? 'रक्षक (A-Z)' : 'Guard (A-Z)';
  static String get guardZA => _isMarathi ? 'रक्षक (Z-A)' : 'Guard (Z-A)';
  static String get todayPeriod => _isMarathi ? 'आज' : 'Today';
  static String get last7DaysPeriod => _isMarathi ? 'मागील ७ दिवस' : 'Last 7 Days';
  static String get last30DaysPeriod => _isMarathi ? 'मागील ३० दिवस' : 'Last 30 Days';
  static String get thisYearPeriod => _isMarathi ? 'या वर्षी' : 'This Year';
  static String get customDateRangePeriod => _isMarathi ? 'सानुकूल तारीख श्रेणी' : 'Custom Date Range';
  static String get noMatchingRecords => _isMarathi
      ? 'निवडलेल्या फिल्टरसाठी कोणतेही रेकॉर्ड सापडले नाहीत.'
      : 'No records found for the selected filters.';

  // ---------------------------------------------------------------------------
  // RECURRING SHIFT SCHEDULING
  // ---------------------------------------------------------------------------
  static String get assignmentType => _isMarathi ? 'असाइनमेंट प्रकार' : 'Assignment Type';
  static String get oneDay => _isMarathi ? 'एक दिवस' : 'One Day';
  static String get recurringSchedule => _isMarathi ? 'आवर्ती वेळापत्रक' : 'Recurring Schedule';
  static String get startDate => _isMarathi ? 'सुरू होण्याची तारीख' : 'Start Date';
  static String get endDate => _isMarathi ? 'समाप्ती तारीख' : 'End Date';
  static String get repeatOn => _isMarathi ? 'पुनरावृत्तीचे वार' : 'Repeat On';
  static String get createSchedule => _isMarathi ? 'वेळापत्रक तयार करा' : 'Create Schedule';
  static String get shiftSchedules => _isMarathi ? 'पाळी वेळापत्रक' : 'Shift Schedules';
  static String get scheduleCreatedSuccess => _isMarathi ? 'आवर्ती वेळापत्रक यशस्वीरित्या तयार झाले.' : 'Recurring schedule created successfully.';
  static String get scheduleCancelledSuccess => _isMarathi ? 'वेळापत्रक रद्द केले गेले.' : 'Schedule cancelled successfully.';
  static String get schedulePausedSuccess => _isMarathi ? 'वेळापत्रक थांबवले गेले.' : 'Schedule paused successfully.';
  static String get scheduleResumedSuccess => _isMarathi ? 'वेळापत्रक पुन्हा सुरू केले.' : 'Schedule resumed successfully.';
  static String get skipDate => _isMarathi ? 'तारीख वगळा' : 'Skip Date';
  static String get skipDateSuccess => _isMarathi ? 'तारीख यशस्वीरित्या वगळली.' : 'Date skipped successfully.';
  static String get reassignGuard => _isMarathi ? 'रक्षक बदला' : 'Reassign Guard';
  static String get guardReassignedSuccess => _isMarathi ? 'रक्षक यशस्वीरित्या बदलला.' : 'Guard reassigned successfully.';
  static String get shiftOverlapError => _isMarathi
      ? 'या Guard च्या विद्यमान शिफ्टसोबत या शिफ्टची वेळ overlap होत आहे.'
      : 'This shift overlaps with an existing shift for this Guard.';
  static String get atLeastOneWeekdayRequired => _isMarathi
      ? 'कृपया किमान एक वार निवडा.'
      : 'Please select at least one weekday.';
  static String get endDateBeforeStartDateError => _isMarathi
      ? 'समाप्ती तारीख सुरू होण्याच्या तारखेपूर्वी असू शकत नाही.'
      : 'End Date cannot be before Start Date.';
  static String get dayMonday => _isMarathi ? 'सोमवार' : 'Monday';
  static String get dayTuesday => _isMarathi ? 'मंगळवार' : 'Tuesday';
  static String get dayWednesday => _isMarathi ? 'बुधवार' : 'Wednesday';
  static String get dayThursday => _isMarathi ? 'गुरुवार' : 'Thursday';
  static String get dayFriday => _isMarathi ? 'शुक्रवार' : 'Friday';
  static String get daySaturday => _isMarathi ? 'शनिवार' : 'Saturday';
  static String get daySunday => _isMarathi ? 'रविवार' : 'Sunday';
  static String get pause => _isMarathi ? 'थांबवा' : 'Pause';
  static String get resume => _isMarathi ? 'सुरू करा' : 'Resume';
  static String get viewDetails => _isMarathi ? 'तपशील पहा' : 'View Details';
  static String get noSchedulesFound => _isMarathi ? 'कोणतेही वेळापत्रक सापडले नाही.' : 'No schedules found.';
  static String get editCapacity => _isMarathi ? 'क्षमता संपादित करा' : 'Edit Capacity';
  static String get saveChanges => _isMarathi ? 'बदल जतन करा' : 'Save Changes';
  static String get totalCapacity => _isMarathi ? 'एकूण क्षमता' : 'Total Capacity';
  static String get totalOccupied => _isMarathi ? 'एकूण भरलेली' : 'Total Occupied';
  static String get totalAvailable => _isMarathi ? 'एकूण उपलब्ध' : 'Total Available';
  static String get capacityUpdatedSuccess => _isMarathi
      ? 'पार्किंग क्षमता यशस्वीरित्या अद्ययावत केली.'
      : 'Parking capacity updated successfully.';
  static String fourWheelerCapacityError(int occupied) => _isMarathi
      ? 'Four-Wheeler ची क्षमता सध्याच्या $occupied वाहनांपेक्षा कमी असू शकत नाही.'
      : 'Four-Wheeler capacity cannot be less than the current occupied vehicles ($occupied).';
  static String twoWheelerCapacityError(int occupied) => _isMarathi
      ? 'Two-Wheeler ची क्षमता सध्याच्या $occupied वाहनांपेक्षा कमी असू शकत नाही.'
      : 'Two-Wheeler capacity cannot be less than the current occupied vehicles ($occupied).';
  static String get fourWheelerParkingFull => _isMarathi
      ? 'चारचाकी पार्किंग पूर्ण भरले आहे. सध्या जागा उपलब्ध नाही.'
      : 'Four-Wheeler parking is full. No space is currently available.';
  static String get twoWheelerParkingFull => _isMarathi
      ? 'दुचाकी पार्किंग पूर्ण भरले आहे. सध्या जागा उपलब्ध नाही.'
      : 'Two-Wheeler parking is full. No space is currently available.';
  static String get financialResponsibility => _isMarathi ? 'आर्थिक जबाबदारी' : 'Financial Responsibility';
  static String get cashOutstanding => _isMarathi ? 'शिल्लक रोख' : 'Cash Outstanding';
  static String get upiOutstanding => _isMarathi ? 'शिल्लक UPI' : 'UPI Outstanding';
  static String get parkingCapacity => _isMarathi ? 'पार्किंग क्षमता' : 'Parking Capacity';
  static String get pendingHandovers => _isMarathi ? 'प्रलंबित हस्तांतरण' : 'Pending Handovers';
  static String get pendingWithdrawals => _isMarathi ? 'प्रलंबित पैसे काढणे' : 'Pending Withdrawals';
  static String get shiftOverview => _isMarathi ? 'पाळी आढावा' : 'Shift Overview';
  static String get completedToday => _isMarathi ? 'आज पूर्ण झालेल्या' : 'Completed Today';
  static String get viewShiftManagement => _isMarathi ? 'पाळी व्यवस्थापन पहा' : 'View Shift Management';
  static String get handoverWithdrawalActivity => _isMarathi ? 'हस्तांतरण / पैसे काढणे व्यवहार' : 'Handover & Withdrawal Activity';
  static String get recentNotifications => _isMarathi ? 'अलीकडील सूचना' : 'Recent Notifications';
  static String get quickNavigation => _isMarathi ? 'जलद कृती' : 'Quick Actions';
  static String get cashManagement => _isMarathi ? 'रोख व्यवस्थापन' : 'Cash Management';
  static String get upiManagement => _isMarathi ? 'UPI व्यवस्थापन' : 'UPI Management';
  static String get operationSettings => _isMarathi ? 'कामकाज सेटिंग्ज' : 'Operation Settings';
  static String get unableToLoadData => _isMarathi
      ? 'डॅशबोर्ड डेटा लोड करण्यात अयशस्वी. कृपया पुन्हा प्रयत्न करा.'
      : 'Unable to load dashboard data. Please retry.';

  // ---------------------------------------------------------------------------
  // GUARD FINANCIAL REPORT & ADMIN SHIFT CONTROL
  // ---------------------------------------------------------------------------
  static String get viewReport => _isMarathi ? 'अहवाल पहा' : 'View Report';
  static String get startShift => _isMarathi ? 'पाळी सुरू करा' : 'Start Shift';
  static String get endShift => _isMarathi ? 'पाळी समाप्त करा' : 'End Shift';
  static String get outstanding => _isMarathi ? 'शिल्लक' : 'Outstanding';
  static String get totalOutstanding => _isMarathi ? 'एकूण शिल्लक' : 'Total Outstanding';
  static String get guardFinancialReport => _isMarathi ? 'सुरक्षा रक्षक आर्थिक अहवाल' : 'Guard Financial Report';
  static String get guardFinancialSummary => _isMarathi ? 'सुरक्षा रक्षक आर्थिक सारांश' : 'Guard Financial Summary';
  static String get last7Days => _isMarathi ? 'मागील ७ दिवस' : 'Last 7 Days';
  static String get last30Days => _isMarathi ? 'मागील ३० दिवस' : 'Last 30 Days';
  static String get thisYear => _isMarathi ? 'चालू वर्ष' : 'This Year';
  static String get customDateRange => _isMarathi ? 'सानुकूल तारीख श्रेणी' : 'Custom Date Range';
  static String get fromDate => _isMarathi ? 'दिनांकापासून' : 'From Date';
  static String get toDate => _isMarathi ? 'दिनांकापर्यंत' : 'To Date';
  static String get fromDateAfterToDateError => _isMarathi
      ? 'सुरुवातीचा दिनांक शेवटच्या दिनांकापेक्षा नंतरचा असू शकत नाही'
      : 'From Date cannot be after To Date';
  static String get startShiftConfirmTitle => _isMarathi ? 'पाळी सुरू करायची?' : 'Start Shift?';
  static String get endShiftConfirmTitle => _isMarathi ? 'पाळी समाप्त करायची?' : 'End Shift?';
  static String get shiftStarted => _isMarathi ? 'पाळी सुरू झाली' : 'Shift Started';
  static String get shiftEnded => _isMarathi ? 'पाळी समाप्त झाली' : 'Shift Ended';
  static String get alreadyActive => _isMarathi
      ? 'या Guard ची आधीच एक Active Shift आहे.'
      : 'This guard already has an active shift.';
  static String get noShift => _isMarathi ? 'कोणतीही सक्रिय पाळी नाही' : 'No Active Shift';
  static String get unableToLoadGuards => _isMarathi
      ? 'सुरक्षा रक्षक माहिती लोड करण्यात अक्षम.'
      : 'Unable to load guard information.';
  static String get scheduledEnd => _isMarathi ? 'नियोजित समाप्ती' : 'Scheduled End';
  static String get currentTime => _isMarathi ? 'वर्तमान वेळ' : 'Current Time';
  static String get shiftDuration => _isMarathi ? 'कालावधी' : 'Duration';
  static String get outstandingWarning => _isMarathi
      ? 'या सुरक्षा रक्षकाकडे शिल्लक आर्थिक जबाबदारी आहे.'
      : 'This guard has outstanding financial responsibility.';
  static String get sevenDayTotal => _isMarathi ? '७-दिवसीय एकूण' : '7-Day Total';
  static String get thirtyDayTotal => _isMarathi ? '३०-दिवसीय एकूण' : '30-Day Total';
  static String get yearTotal => _isMarathi ? 'वार्षिक एकूण' : 'Year Total';
  static String get periodTotal => _isMarathi ? 'कालावधी एकूण' : 'Period Total';
  static String get cashAdvances => _isMarathi ? 'रोख अ‍ॅडव्हान्स' : 'Cash Advances';
  static String get cashFinal => _isMarathi ? 'रोख अंतिम' : 'Cash Final';
  static String get cashRefunds => _isMarathi ? 'रोख परतावा' : 'Cash Refunds';
  static String get upiAdvances => _isMarathi ? 'UPI अ‍ॅडव्हान्स' : 'UPI Advances';
  static String get upiFinal => _isMarathi ? 'UPI अंतिम' : 'UPI Final';
  static String get upiRefunds => _isMarathi ? 'UPI परतावा' : 'UPI Refunds';
  static String get cashTransactions => _isMarathi ? 'रोख व्यवहार' : 'Cash Transactions';
  static String get upiTransactions => _isMarathi ? 'UPI व्यवहार' : 'UPI Transactions';
  static String get allGuards => _isMarathi ? 'सर्व सुरक्षा रक्षक' : 'All Guards';
  static String get totalCash => _isMarathi ? 'एकूण रोख' : 'Total Cash';
  static String get totalUpi => _isMarathi ? 'एकूण UPI' : 'Total UPI';
  static String get shiftStartedNotificationGuard => _isMarathi
      ? 'Admin ने तुमची Shift सुरू केली आहे.'
      : 'Your shift has been started by Admin.';
  static String get shiftEndedNotificationGuard => _isMarathi
      ? 'Admin ने तुमची Shift समाप्त केली आहे.'
      : 'Your shift has been ended by Admin.';

  // GUARD REPORTS & FINANCIAL
  static String get guardReports => _isMarathi ? 'रक्षक अहवाल' : 'Guard Reports';
  static String get withdrawalHistory => _isMarathi ? 'पैसे काढण्याचा इतिहास' : 'Withdrawal History';
  static String get handoverHistory => _isMarathi ? 'हस्तांतरण इतिहास' : 'Handover History';
  static String get withdrawnByAdmin => _isMarathi ? 'ॲडमिनद्वारे काढलेले' : 'Withdrawn by Admin';
  static String get invalidDateRange => _isMarathi
      ? 'सुरुवातीची तारीख शेवटच्या तारखेपेक्षा आधी किंवा समान असावी.'
      : 'From Date must be before or equal to To Date.';
  static String get customPeriodTotal => _isMarathi ? 'सानुकूल कालावधी एकूण' : 'Custom Period Total';
  static String get sevenDaysTotal => _isMarathi ? '७ दिवसांची एकूण' : '7 Days Total';
  static String get thirtyDaysTotal => _isMarathi ? '३० दिवसांची एकूण' : '30 Days Total';
  static String get entriesCount => _isMarathi ? 'प्रवेश' : 'Entries';
  static String get exitsCount => _isMarathi ? 'बाहेर' : 'Exits';
  static String get cashAdvance => _isMarathi ? 'रोख आगाऊ' : 'Cash Advance';
  static String get cashRefund => _isMarathi ? 'रोख परतावा' : 'Cash Refund';
  static String get upiAdvance => _isMarathi ? 'UPI आगाऊ' : 'UPI Advance';
  static String get upiRefund => _isMarathi ? 'UPI परतावा' : 'UPI Refund';
  static String get transactionHistory => _isMarathi ? 'व्यवहार इतिहास' : 'Transaction History';
  static String get financialResponsibilityTitle => _isMarathi ? 'आर्थिक जबाबदारी' : 'Financial Responsibility';

  // ---------------------------------------------------------------------------
  // MONTHLY PASS
  // ---------------------------------------------------------------------------
  static String get monthlyPasses => _isMarathi ? 'मासिक पासेस' : 'Monthly Passes';
  static String get passes => _isMarathi ? 'पासेस' : 'Passes';
  static String get monthlyPassManagement => _isMarathi ? 'मासिक पास व्यवस्थापन' : 'Monthly Pass Management';
  static String get createMonthlyPass => _isMarathi ? 'मासिक पास तयार करा' : 'Create Monthly Pass';
  static String get activePasses => _isMarathi ? 'सक्रिय पासेस' : 'Active Passes';
  static String get expiringSoon => _isMarathi ? 'लवकरच संपणारे' : 'Expiring Soon';
  static String get expiredPasses => _isMarathi ? 'मुदत संपलेले पासेस' : 'Expired Passes';
  static String get passCollection => _isMarathi ? 'पास संकलन' : 'Pass Collection';
  static String get viewAllPasses => _isMarathi ? 'सर्व पासेस पहा' : 'View All Passes';
  static String get mustBeGreaterThanZero => _isMarathi ? 'शून्यापेक्षा जास्त असावे' : 'Must be > 0';
  static String get invalidAmount => _isMarathi ? 'अवैध रक्कम' : 'Invalid amount';
  static String get connectingShiftStatus => _isMarathi ? 'पाळी स्थितीशी जोडत आहे...' : 'Connecting to shift status...';
  static String get entryBlocked => _isMarathi ? 'प्रवेश अवरोधित' : 'Entry Blocked';
  static String get noActiveShiftAssignedWarning => _isMarathi
      ? 'तुम्हाला कोणतीही सक्रिय पाळी नियुक्त केलेली नाही. वाहन प्रवेश अवरोधित केला आहे. कृपया ॲडमिनशी संपर्क साधा.'
      : 'No active shift is assigned to you. Vehicle entry is blocked. Please contact Admin.';
  static String get bluetoothPrinter => _isMarathi ? 'ब्लूटूथ प्रिंटर (MPT-II)' : 'Bluetooth Printer (MPT-II)';
  static String get guardProfile => _isMarathi ? 'सुरक्षा रक्षक प्रोफाइल' : 'Guard Profile';
  static String get noWithdrawalRecordsFound => _isMarathi ? 'कोणत्याही पैसे काढण्याच्या नोंदी आढळल्या नाहीत.' : 'No withdrawal records found.';
  static String get withdrawalByAdmin => _isMarathi ? 'ॲडमिनद्वारे काढलेले' : 'Withdrawal by Admin';
  static String get exitExamples => _isMarathi ? 'उदा: MH23ER5656, 5656, 1004' : 'Examples: MH23ER5656, 5656, 1004';
  static String get currentEstimatedFee => _isMarathi ? 'सध्याचे अंदाजे शुल्क' : 'Current Estimated Fee';
  static String get estimatedBalanceDue => _isMarathi ? 'अंदाजे देय रक्कम' : 'Estimated Balance Due';
  static String get estimatedRefund => _isMarathi ? 'अंदाजे परतावा' : 'Estimated Refund';
  static String get passAmount => _isMarathi ? 'मासिक पास रक्कम' : 'Monthly Pass Amount';
  static String get fullPaymentInAdvance => _isMarathi ? 'संपूर्ण ₹६०० आगाऊ रक्कम' : 'FULL ₹600 IN ADVANCE';
  static String get pay600AndCreatePass => _isMarathi ? '₹६०० भरा आणि पास तयार करा' : 'Pay ₹600 & Create Pass';
  static String get monthlyPassPaymentFailed => _isMarathi ? 'मासिक पास पेमेंट अयशस्वी झाले. कृपया पुन्हा प्रयत्न करा.' : 'Monthly Pass payment failed. Please try again.';
  static String get monthlyPassExpiredNotice => _isMarathi ? 'मासिक पासची मुदत संपली आहे. सामान्य पार्किंग शुल्क लागू राहील.' : 'Monthly Pass expired. Normal parking charges apply.';
  static String get monthlyPassUpcomingNotice => _isMarathi ? 'मासिक पास आगामी कालावधीसाठी आहे. सामान्य पार्किंग शुल्क लागू राहील.' : 'Monthly Pass upcoming. Normal parking charges apply.';
  static String get monthlyPassOverlapNotice => _isMarathi ? 'या वाहनासाठी या कालावधीत आधीच मासिक पास उपलब्ध आहे.' : 'This vehicle already has a Monthly Pass for this period.';
  static String get renewPass => _isMarathi ? 'पास नूतनीकरण' : 'Renew Pass';
  static String get passNumber => _isMarathi ? 'पास क्रमांक' : 'Pass Number';
  static String get validTill => _isMarathi ? 'वैधता दिनांक' : 'Valid Till';
  static String get customerName => _isMarathi ? 'ग्राहकाचे नाव' : 'Customer Name';
  static String get customerNameRequired => _isMarathi ? 'ग्राहकाचे नाव आवश्यक आहे' : 'Customer name is required';
  static String get searchPassHint => _isMarathi ? 'वाहन क्र. / पास क्र. / मोबाईल' : 'Vehicle Number / Pass Number / Mobile';
  static String get noPassesFound => _isMarathi ? 'कोणतेही मासिक पास आढळले नाहीत' : 'No monthly passes found';
  static String get unableToLoadMonthlyPasses => _isMarathi ? 'मासिक पास लोड करण्यात अयशस्वी.' : 'Unable to load Monthly Passes.';
  static String get upcomingPasses => _isMarathi ? 'आगामी पासेस' : 'Upcoming Passes';
  static String get paymentStatusPaid => _isMarathi ? 'भरले (PAID)' : 'PAID';
  static String get advanceNotRequiredForPass => _isMarathi ? 'मासिक पास वाहनासाठी आगाऊ रक्कम आवश्यक नाही' : 'Advance payment not required for Monthly Pass vehicle';
  static String get parkingFee => _isMarathi ? 'पार्किंग शुल्क' : 'Parking Fee';
  static String get yes => _isMarathi ? 'होय' : 'Yes';
  static String get validity => _isMarathi ? 'वैधता' : 'Validity';
  static String get payment => _isMarathi ? 'पेमेंट' : 'Payment';
  static String get paid => _isMarathi ? 'भरले' : 'PAID';
  static String get print => _isMarathi ? 'प्रिंट' : 'Print';
  static String get mobile => _isMarathi ? 'मोबाईल' : 'Mobile';
  static String get masterAdmin => _isMarathi ? 'मास्टर ॲडमिन' : 'Master Admin';
  static String get roleAdmin => _isMarathi ? 'ॲडमिन' : 'ADMIN';
  static String get full => _isMarathi ? 'पूर्ण' : 'FULL';
  static String get checkingMonthlyPass => _isMarathi ? 'मासिक पास तपासत आहे...' : 'Checking Monthly Pass...';
  static String get monthlyPassVehicleTypeMismatch => _isMarathi
      ? 'मासिक पास वाहन प्रकार जुळत नाही.'
      : 'Monthly Pass vehicle type mismatch.';
  static String get monthlyPassMismatchWarning => _isMarathi
      ? 'पास लागू नाही. नियमित वाहनतळ शुल्क आकारले जाईल.'
      : 'Pass not applicable. Normal parking charges apply.';
  static String get passVehicleType => _isMarathi ? 'पास प्रकार' : 'Pass Type';
  static String get selectedVehicleType => _isMarathi ? 'निवडलेला प्रकार' : 'Selected Type';
  static String get vehicleTypeLockedByMonthlyPass => _isMarathi
      ? 'नोंदणीकृत मासिक पासमुळे वाहन प्रकार लॉक केला आहे.'
      : 'Vehicle type is locked by registered Monthly Pass.';
  static String get lockedByMonthlyPass => _isMarathi ? 'मासिक पासद्वारे लॉक' : 'Locked by Monthly Pass';
  static String get viewParkingHistory => _isMarathi ? 'पार्किंग इतिहास पहा' : 'View Parking History';
  static String get monthlyPassParkingHistory => _isMarathi ? 'मासिक पास पार्किंग इतिहास' : 'Monthly Pass Parking History';
  static String get totalVisits => _isMarathi ? 'एकूण भेटी' : 'Total Visits';
  static String get noParkingVisitsRecorded => _isMarathi
      ? 'या मासिक पास वाहनासाठी कोणत्याही पार्किंग नोंदी आढळल्या नाहीत.'
      : 'No parking visits recorded for this Monthly Pass vehicle.';
  static String get searchTicketOrDate => _isMarathi ? 'तिकीट क्र. किंवा तारीख शोधा' : 'Search Ticket or Date';
  static String get view => _isMarathi ? 'पहा' : 'View';
  static String get select => _isMarathi ? 'निवडा' : 'Select';
  static String get sort => _isMarathi ? 'क्रमवारी' : 'Sort';
  static String get change => _isMarathi ? 'बदला' : 'Change';
  static String get shift1Morning => _isMarathi ? 'पाळी १ (सकाळ ०६:०० - १४:००)' : 'Shift 1 (Morning 06:00 - 14:00)';
  static String get shift2Evening => _isMarathi ? 'पाळी २ (दुपार १४:०० - २२:००)' : 'Shift 2 (Evening 14:00 - 22:00)';
  static String get shift3Night => _isMarathi ? 'पाळी ३ (रात्र २२:०० - ०६:००)' : 'Shift 3 (Night 22:00 - 06:00)';
  static String get last15Days => _isMarathi ? 'मागील १५ दिवस' : 'Last 15 Days';
  static String get custom => _isMarathi ? 'सानुकूल' : 'Custom';
  static String get fromDateMustBeBeforeToDate => _isMarathi ? 'प्रारंभ तारीख समाप्ती तारखेच्या आधी किंवा समान असावी' : 'From Date must be before or equal to To Date';
  static String get fromDateCannotBeAfterToDate => _isMarathi ? 'प्रारंभ तारीख समाप्ती तारखेनंतर असू शकत नाही' : 'From Date cannot be after To Date';
  static String get noReceivingGuardAvailable => _isMarathi ? 'हस्तांतरणासाठी कोणताही रक्षक उपलब्ध नाही' : 'No Receiving Guard Available';
  static String get noReceivingGuardMessage => _isMarathi ? 'हस्तांतरण स्वीकारण्यासाठी सिस्टममध्ये इतर कोणतेही सक्रिय रक्षक उपलब्ध नाहीत. कृपया ॲडमिनशी संपर्क साधा.' : 'No other active guards are currently configured in the system to receive this handover. Please contact Admin.';
  static String get fullOutstandingAmount => _isMarathi ? 'संपूर्ण शिल्लक रक्कम' : 'FULL OUTSTANDING AMOUNT';
  static String get partialHandoversNotPermitted => _isMarathi ? 'अंशतः हस्तांतरणास परवानगी नाही. संपूर्ण शिल्लक हस्तांतरित केली जाईल.' : 'Partial handovers are not permitted. The full outstanding balance will be transferred.';
  static String get selectReceivingGuard => _isMarathi ? 'स्वीकारणारा रक्षक निवडा' : 'Select Receiving Guard';
  static String get acceptHandover => _isMarathi ? 'हस्तांतरण स्वीकारा' : 'Accept Handover';
  static String get reject => _isMarathi ? 'नाकारा' : 'Reject';
  static String get cancelHandover => _isMarathi ? 'हस्तांतरण रद्द करा' : 'Cancel Handover';
  static String get pendingHandoverRequest => _isMarathi ? 'प्रलंबित हस्तांतरण विनंती' : 'Pending Handover Request';
  static String get keepFullWithMe => _isMarathi ? 'संपूर्ण रक्कम स्वतःकडे ठेवा' : 'Keep Full With Me';
  static String get unableToLoadKeepWithMe => _isMarathi ? 'स्वतःकडे ठेवलेला इतिहास लोड करण्यात अयशस्वी. कृपया पुन्हा प्रयत्न करा.' : 'Unable to load Keep With Me history. Please try again.';
  static String get unableToLoadHandovers => _isMarathi ? 'हस्तांतरण इतिहास लोड करण्यात अयशस्वी. कृपया पुन्हा प्रयत्न करा.' : 'Unable to load handover history. Please try again.';
  static String get unableToLoadWithdrawals => _isMarathi ? 'पैसे काढण्याचा इतिहास लोड करण्यात अयशस्वी. कृपया पुन्हा प्रयत्न करा.' : 'Unable to load withdrawal history. Please try again.';
  static String get unableToLoadResponsibility => _isMarathi ? 'जबाबदारी इतिहास लोड करण्यात अयशस्वी. कृपया पुन्हा प्रयत्न करा.' : 'Unable to load responsibility history. Please try again.';
  static String get keepWithMeHistory => _isMarathi ? 'स्वतःकडे ठेवलेला इतिहास' : 'Keep With Me History';
  static String get responsibility => _isMarathi ? 'जबाबदारी' : 'Responsibility';
  static String get monFri => _isMarathi ? 'सोम-शुक्र' : 'Mon-Fri';
  static String get all7Days => _isMarathi ? 'सर्व ७ दिवस' : 'All 7 Days';
  static String get exceptionsAndOverrides => _isMarathi ? 'अपवाद व बदल' : 'Exceptions & Overrides';
  static String get noExceptionsRecorded => _isMarathi ? 'कोणतेही अपवाद नोंदवलेले नाहीत.' : 'No exceptions recorded.';
  static String get facilityNameEnglish => _isMarathi ? 'वाहनतळ नाव (English)' : 'Facility Name (English)';
  static String get facilityNameMarathi => _isMarathi ? 'वाहनतळ नाव (मराठी)' : 'Facility Name (मराठी)';
  static String get addressEnglish => _isMarathi ? 'पत्ता / ठिकाण (English)' : 'Address / Location (English)';
  static String get addressMarathi => _isMarathi ? 'पत्ता / ठिकाण (मराठी)' : 'Address / Location (मराठी)';
  static String get contactPhone => _isMarathi ? 'संपर्क फोन' : 'Contact Phone';
  static String get contactPhoneMarathi => _isMarathi ? 'संपर्क फोन (मराठी)' : 'Contact Phone (मराठी)';
  static String get systemSecurityAuditTrail => _isMarathi ? 'प्रणाली सुरक्षा व ऑडिट ट्रेल' : 'System Security & Audit Trail';
  static String get auditTrailDescription => _isMarathi ? 'प्रशासकीय नोंदी, रक्षक निर्मिती, पाळी बदल आणि कॉन्फिगरेशन बदलांचा अपरिवर्तनीय इतिहास पहा.' : 'View the immutable log of administrative events, guard creations, shift reassignments, and configuration changes.';
  static String get viewAuditLogs => _isMarathi ? 'ऑडिट लॉग पहा' : 'View Audit Logs';
  static String get startDateSort => _isMarathi ? 'प्रारंभ तारीख' : 'Start Date';
  static String get endDateSort => _isMarathi ? 'समाप्ती तारीख' : 'End Date';
  static String get guardNameSort => _isMarathi ? 'रक्षकाचे नाव (A-Z)' : 'Guard Name (A-Z)';
  static String get createdDateSort => _isMarathi ? 'तयार दिनांक' : 'Created Date';
  static String get firstHour => _isMarathi ? 'पहिला तास' : '1st Hour';
  static String get additionalHour => _isMarathi ? 'पुढील तास' : 'Additional Hour';
  static String get twelveHourCap => _isMarathi ? '१२-तास मर्यादा' : '12-Hour Cap';
  static String get optional => _isMarathi ? 'पर्यायी' : 'Optional';

  // Handover Acceptance Modal Strings
  static String get handoverReceived => _isMarathi ? 'हँडओव्हर प्राप्त झाला' : 'Handover Received';
  static String get method => _isMarathi ? 'पद्धत' : 'Method';
  static String get pleaseAcceptHandoverToContinue => _isMarathi ? 'पुढे सुरू ठेवण्यासाठी हे हँडओव्हर स्वीकारा.' : 'Please accept this handover to continue.';
  static String get accept => _isMarathi ? 'स्वीकारा' : 'Accept';
  static String get handoverAcceptedSuccess => _isMarathi ? 'हँडओव्हर यशस्वीरीत्या स्वीकारले.' : 'Handover accepted successfully.';
  static String get handoverStaleAmountError => _isMarathi ? 'हँडओव्हरची रक्कम बदलली आहे. कृपया नवीन हँडओव्हर तयार करा.' : 'Handover amount has changed. Please create a new handover.';
  static String get unableToAcceptHandover => _isMarathi ? 'हँडओव्हर स्वीकारता आला नाही. कृपया पुन्हा प्रयत्न करा.' : 'Unable to accept handover. Please try again.';

  // ---------------------------------------------------------------------------
  // FACTORY FOR SCOPED STRINGS (Backwards compatibility)
  // ---------------------------------------------------------------------------
  static AppLocaleStrings get(AppLanguage lang) => AppLocaleStrings(lang);
  static AppLocaleStrings get currentLocale => AppLocaleStrings(_currentLang);
}

/// Encapsulates language-scoped strings for explicit language instances.
class AppLocaleStrings {
  final AppLanguage language;
  const AppLocaleStrings(this.language);

  bool get isMarathi => language == AppLanguage.marathi;

  String get languageSettingsTitle => isMarathi ? 'भाषा व सेटिंग्ज' : 'Language & Settings';
  String get appUiLanguageSection => isMarathi ? 'अ‍ॅपची मुख्य भाषा' : 'Application Language';
  String get langEnglish => 'English';
  String get langMarathi => 'मराठी (Marathi)';
  String get businessProfileSection => isMarathi ? 'पार्किंग व्यवसायाची माहिती' : 'Business Profile';
  String get bizflowBrandingSwitch => isMarathi
      ? 'पावतीवर BizFlow ब्रँडिंग दाखवा'
      : 'Show BizFlow Branding on Receipt';
  String get settingsSavedNotice => isMarathi ? 'सेटिंग्ज जतन केल्या आहेत.' : 'Settings saved successfully.';
  String get cancel => isMarathi ? 'रद्द करा' : 'Cancel';
  String get save => isMarathi ? 'जतन करा' : 'Save';
  String get businessMobileLabel => isMarathi ? 'मो.' : 'Mo.';
}
