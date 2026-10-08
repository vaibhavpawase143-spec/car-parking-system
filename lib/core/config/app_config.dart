/// Supported deployment environments.
enum AppEnvironment {
  dev,
  prod;

  static AppEnvironment fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'dev':
      case 'development':
      default:
        return AppEnvironment.dev;
    }
  }
}

/// Centralized configuration provider for DEV and PROD environments.
/// All values are client-safe public configurations.
/// Secrets (such as API Secrets or Private Keys) are strictly prohibited.
///
/// PROD deployment must supply values via --dart-define:
///   flutter build web \
///     --dart-define=APP_ENV=prod \
///     --dart-define=CLOUDINARY_CLOUD_NAME=`CLIENT_CLOUD_NAME` \
///     --dart-define=CLOUDINARY_UPLOAD_PRESET=`CLIENT_UNSIGNED_PRESET`
///
/// Firebase PROD configuration:
///   Re-generate firebase_options.dart for the client's Firebase project
///   using FlutterFire CLI. Do NOT hardcode client Firebase credentials.
class AppConfig {
  final AppEnvironment environment;
  final String firebaseProjectId;
  final String cloudinaryCloudName;
  final String cloudinaryUploadPreset;
  final String cloudinaryFolder;
  final String cloudinaryApiKey;
  final String cloudinaryApiSecret;
  final String cloudinaryDeleteUrl;

  const AppConfig({
    required this.environment,
    required this.firebaseProjectId,
    required this.cloudinaryCloudName,
    required this.cloudinaryUploadPreset,
    this.cloudinaryFolder = 'parking_records',
    this.cloudinaryApiKey = '',
    this.cloudinaryApiSecret = '',
    this.cloudinaryDeleteUrl = '',
  });

  bool get isDevelopment => environment == AppEnvironment.dev;
  bool get isProduction => environment == AppEnvironment.prod;
  String get uploadUrl => 'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';

  /// Active configuration resolved at compile/run time via `--dart-define`.
  /// DEV fallbacks use the verified unsigned preset for car-parking-system development.
  static final AppConfig current = _resolveConfig();

  static AppConfig _resolveConfig() {
    const envRaw = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    final env = AppEnvironment.fromString(envRaw);

    // DEV: Cloud Name = dwzlw6jeu | Upload Preset = car_parking_dev (Unsigned mode)
    const cloudName = String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: 'dwzlw6jeu',
    );

    const uploadPreset = String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: 'car_parking_dev',
    );

    const projectId = String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'car-parking-system-2026',
    );

    const folder = String.fromEnvironment(
      'CLOUDINARY_FOLDER',
      defaultValue: 'parking_records',
    );

    const apiKey = String.fromEnvironment(
      'CLOUDINARY_API_KEY',
      defaultValue: '',
    );

    const apiSecret = String.fromEnvironment(
      'CLOUDINARY_API_SECRET',
      defaultValue: '',
    );

    const deleteUrl = String.fromEnvironment(
      'CLOUDINARY_DELETE_URL',
      defaultValue: '',
    );

    return AppConfig(
      environment: env,
      firebaseProjectId: projectId,
      cloudinaryCloudName: cloudName,
      cloudinaryUploadPreset: uploadPreset,
      cloudinaryFolder: folder,
      cloudinaryApiKey: apiKey,
      cloudinaryApiSecret: apiSecret,
      cloudinaryDeleteUrl: deleteUrl,
    );
  }
}
