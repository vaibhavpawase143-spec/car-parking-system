/// Supported application and receipt languages.
enum AppLanguage {
  english('en', 'English'),
  marathi('mr', 'मराठी');

  final String code;
  final String displayName;

  const AppLanguage(this.code, this.displayName);

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.english;
    switch (code.trim().toLowerCase()) {
      case 'mr':
      case 'marathi':
        return AppLanguage.marathi;
      case 'en':
      case 'english':
      default:
        return AppLanguage.english;
    }
  }
}
