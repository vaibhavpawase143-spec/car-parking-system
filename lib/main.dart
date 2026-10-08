import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/config/business_profile.dart';
import 'core/localization/app_language_controller.dart';
import 'core/localization/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/guard/auth/auth_gate.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize persistent App Language, Business Profile, and Dynamic Settings
  await AppLanguageController.instance.init();
  await BusinessProfileController.instance.init();
  await SettingsService.instance.init();

  runApp(const CarParkingApp());
}

class CarParkingApp extends StatelessWidget {
  const CarParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguageController.instance,
      builder: (context, _) {
        return AppLanguageScope(
          controller: AppLanguageController.instance,
          child: MaterialApp(
            key: ValueKey(AppLanguageController.instance.currentLanguage),
            debugShowCheckedModeBanner: false,
            title: AppStrings.browserTitle,
            onGenerateTitle: (context) => AppStrings.browserTitle,
            theme: AppTheme.lightTheme,
            builder: (context, child) {
              return AppLanguageScope(
                controller: AppLanguageController.instance,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AuthGate(),
          ),
        );
      },
    );
  }
}