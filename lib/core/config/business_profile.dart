import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configurable profile for the parking business and printed receipt header.
/// Encapsulates the authoritative "CAR PARKING SYSTEM" / "BIZFLOW" branding identity.
class BusinessProfile {
  final String marathiName;
  final String englishName;
  final String marathiAuthority;
  final String marathiLocation;
  final String englishLocation;
  final String mobile;
  final String marathiMobile;
  final bool bizflowBrandingEnabled;

  const BusinessProfile({
    this.marathiName = 'CAR PARKING SYSTEM',
    this.englishName = 'CAR PARKING SYSTEM',
    this.marathiAuthority = 'म. रा. मा. परिवहन महामंडळाचे अधिकृत वाहनतळ',
    this.marathiLocation = 'संगमनेर बसस्थानक',
    this.englishLocation = 'SANGAMNER BUS STAND',
    this.mobile = '9690793434',
    this.marathiMobile = '९६९०७९३४३४',
    this.bizflowBrandingEnabled = true,
  });

  /// Convenience getters for formatting
  String get marathiHeaderTag => '॥ श्री ॥';
  String get marathiGovernmentTag => marathiAuthority;
  String get businessNameMarathi => marathiName;
  String get businessNameEnglish => englishName;
  String get locationMarathi => marathiLocation;
  String get locationEnglish => englishLocation;
  String get mobileFormattedMarathi => 'मो. $marathiMobile';
  String get mobileFormattedEnglish => 'Mo. $mobile';
  String get mobileMarathi => 'मो. $marathiMobile';
  String get mobileEnglish => 'Mo. $mobile';
  String get contactPhone => mobile;
}

/// Singleton controller for managing and persisting Business Profile settings.
class BusinessProfileController extends ChangeNotifier {
  static final BusinessProfileController instance = BusinessProfileController._internal();

  BusinessProfileController._internal();

  static const String _keyMarathiName = 'biz_marathi_name';
  static const String _keyEnglishName = 'biz_english_name';
  static const String _keyMarathiLocation = 'biz_marathi_location';
  static const String _keyEnglishLocation = 'biz_english_location';
  static const String _keyMobile = 'biz_mobile';
  static const String _keyMarathiMobile = 'biz_marathi_mobile';
  static const String _keyBizflowBranding = 'biz_branding_enabled';

  BusinessProfile _profile = const BusinessProfile();
  bool _initialized = false;

  BusinessProfile get profile => _profile;
  static BusinessProfile get current => instance.profile;

  /// Initializes profile from persistent storage.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final mName = prefs.getString(_keyMarathiName);
      final eName = prefs.getString(_keyEnglishName);
      final mLoc = prefs.getString(_keyMarathiLocation);
      final eLoc = prefs.getString(_keyEnglishLocation);
      final mob = prefs.getString(_keyMobile);
      final mMob = prefs.getString(_keyMarathiMobile);
      final branding = prefs.getBool(_keyBizflowBranding);

      final cleanMName = (mName == null || mName.contains('जय गणेश') || mName.toUpperCase().contains('GANESH'))
          ? 'CAR PARKING SYSTEM'
          : mName;
      final cleanEName = (eName == null || eName.contains('जय गणेश') || eName.toUpperCase().contains('GANESH'))
          ? 'CAR PARKING SYSTEM'
          : eName;

      _profile = BusinessProfile(
        marathiName: cleanMName,
        englishName: cleanEName,
        marathiAuthority: 'म. रा. मा. परिवहन महामंडळाचे अधिकृत वाहनतळ',
        marathiLocation: mLoc ?? 'संगमनेर बसस्थानक',
        englishLocation: eLoc ?? 'SANGAMNER BUS STAND',
        mobile: mob ?? '9690793434',
        marathiMobile: mMob ?? '९६९०७९३४३४',
        bizflowBrandingEnabled: branding ?? true,
      );
    } catch (_) {
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Updates and persists the business profile.
  Future<void> updateProfile({
    String? marathiName,
    String? englishName,
    String? marathiLocation,
    String? englishLocation,
    String? mobile,
    String? marathiMobile,
    bool? bizflowBrandingEnabled,
  }) async {
    _profile = BusinessProfile(
      marathiName: marathiName ?? _profile.marathiName,
      englishName: englishName ?? _profile.englishName,
      marathiAuthority: _profile.marathiAuthority,
      marathiLocation: marathiLocation ?? _profile.marathiLocation,
      englishLocation: englishLocation ?? _profile.englishLocation,
      mobile: mobile ?? _profile.mobile,
      marathiMobile: marathiMobile ?? _profile.marathiMobile,
      bizflowBrandingEnabled: bizflowBrandingEnabled ?? _profile.bizflowBrandingEnabled,
    );
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMarathiName, _profile.marathiName);
      await prefs.setString(_keyEnglishName, _profile.englishName);
      await prefs.setString(_keyMarathiLocation, _profile.marathiLocation);
      await prefs.setString(_keyEnglishLocation, _profile.englishLocation);
      await prefs.setString(_keyMobile, _profile.mobile);
      await prefs.setString(_keyMarathiMobile, _profile.marathiMobile);
      await prefs.setBool(_keyBizflowBranding, _profile.bizflowBrandingEnabled);
    } catch (_) {}
  }
}
