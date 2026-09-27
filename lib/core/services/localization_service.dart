import 'package:flutter/foundation.dart';
import '../localization/app_language.dart';
import '../localization/app_localizations.dart';
import 'storage_service.dart';

/// Central state management and persistence service for application localization.
///
/// Implements [ChangeNotifier] so UI components and [MaterialApp] can reactively
/// re-render upon language switching without requiring an app restart.
class LocalizationService extends ChangeNotifier {
  static const String prefLanguageCodeKey = 'pukaar_selected_language_code';
  static const String prefHasSelectedLanguageKey = 'pukaar_has_selected_language';

  final StorageService _storageService;
  AppLanguage _currentLanguage = AppLanguage.english;
  bool _isInitialized = false;

  LocalizationService(this._storageService);

  /// Current active application language.
  AppLanguage get currentLanguage => _currentLanguage;

  /// Current active localization string dictionary.
  AppLocalizations get l10n => AppLocalizations(_currentLanguage);
  AppLocalizations get localizations => l10n;

  /// Active speech-to-text locale matching the current application language (en_IN, hi_IN, mr_IN).
  String get speechLocale => _currentLanguage.speechLocale;

  /// Whether the service has completed loading persisted settings.
  bool get isInitialized => _isInitialized;

  /// Initializes the service by loading persisted language preferences.
  Future<void> init() async {
    try {
      final code = await _storageService.getString(prefLanguageCodeKey);
      if (code != null && code.isNotEmpty) {
        _currentLanguage = AppLanguage.fromCode(code);
      }
    } catch (e) {
      debugPrint('Error loading saved language: $e');
      _currentLanguage = AppLanguage.english;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Whether the user has explicitly completed the initial language selection.
  Future<bool> hasSelectedLanguage() async {
    try {
      final hasSelected = await _storageService.getBool(prefHasSelectedLanguageKey);
      return hasSelected ?? false;
    } catch (e) {
      debugPrint('Error checking hasSelectedLanguage: $e');
      return false;
    }
  }

  /// Changes the active language, updates persistence, and notifies listeners.
  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    try {
      await _storageService.setString(prefLanguageCodeKey, language.code);
      await _storageService.setBool(prefHasSelectedLanguageKey, true);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
    notifyListeners();
  }
}
