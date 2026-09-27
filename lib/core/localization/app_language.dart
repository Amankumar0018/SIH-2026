/// Supported languages for Pukaar emergency platform.
enum AppLanguage {
  english(
    code: 'en',
    nativeName: 'English',
    englishName: 'English',
    speechLocale: 'en_IN',
  ),
  hindi(
    code: 'hi',
    nativeName: 'हिंदी',
    englishName: 'Hindi',
    speechLocale: 'hi_IN',
  ),
  marathi(
    code: 'mr',
    nativeName: 'मराठी',
    englishName: 'Marathi',
    speechLocale: 'mr_IN',
  );

  final String code;
  final String nativeName;
  final String englishName;
  final String speechLocale;

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.speechLocale,
  });

  /// Factory to resolve [AppLanguage] from language code.
  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.english;
    switch (code.toLowerCase()) {
      case 'hi':
      case 'hin':
        return AppLanguage.hindi;
      case 'mr':
      case 'mar':
        return AppLanguage.marathi;
      case 'en':
      case 'eng':
      default:
        return AppLanguage.english;
    }
  }
}
