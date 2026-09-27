import 'package:flutter_test/flutter_test.dart';
import 'package:pukaar/core/localization/app_language.dart';
import 'package:pukaar/core/localization/app_localizations.dart';
import 'package:pukaar/core/models/emergency_enums.dart';
import 'package:pukaar/core/services/localization_service.dart';
import 'package:pukaar/core/services/storage_service.dart';

void main() {
  group('LocalizationService Tests', () {
    late InMemoryStorageService storage;
    late LocalizationService localizationService;

    setUp(() {
      storage = InMemoryStorageService();
      localizationService = LocalizationService(storage);
    });

    test('Initial default language is English when nothing is stored', () async {
      expect(localizationService.currentLanguage, AppLanguage.english);
      expect(localizationService.speechLocale, 'en_IN');
      expect(await localizationService.hasSelectedLanguage(), isFalse);
      expect(localizationService.localizations.signIn, 'Sign In');
    });

    test('Switching to Hindi updates language, speechLocale, notifies listeners, and marks selected', () async {
      int notifyCount = 0;
      localizationService.addListener(() {
        notifyCount++;
      });

      await localizationService.setLanguage(AppLanguage.hindi);

      expect(localizationService.currentLanguage, AppLanguage.hindi);
      expect(localizationService.speechLocale, 'hi_IN');
      expect(await localizationService.hasSelectedLanguage(), isTrue);
      expect(notifyCount, 1);
      expect(localizationService.localizations.signIn, 'साइन इन');
      expect(localizationService.localizations.chooseLanguageTitle, 'भाषा चुनें');
      expect(await storage.getString('pukaar_selected_language_code'), 'hi');
      expect(await storage.getBool('pukaar_has_selected_language'), isTrue);
    });

    test('Switching to Marathi updates language, speechLocale, and persists state', () async {
      await localizationService.setLanguage(AppLanguage.marathi);

      expect(localizationService.currentLanguage, AppLanguage.marathi);
      expect(localizationService.speechLocale, 'mr_IN');
      expect(await localizationService.hasSelectedLanguage(), isTrue);
      expect(localizationService.localizations.chooseLanguageTitle, 'भाषा निवडा');
      expect(localizationService.localizations.signUp, 'नोंदणी करा');
      expect(await storage.getString('pukaar_selected_language_code'), 'mr');
    });

    test('Restores persisted language upon init', () async {
      await storage.setString('pukaar_selected_language_code', 'mr');
      await storage.setBool('pukaar_has_selected_language', true);

      final newService = LocalizationService(storage);
      await newService.init();

      expect(newService.currentLanguage, AppLanguage.marathi);
      expect(newService.speechLocale, 'mr_IN');
      expect(await newService.hasSelectedLanguage(), isTrue);
    });

    test('Fallback to English if invalid stored language code', () async {
      await storage.setString('pukaar_selected_language_code', 'invalid_code');
      await storage.setBool('pukaar_has_selected_language', true);

      final newService = LocalizationService(storage);
      await newService.init();

      expect(newService.currentLanguage, AppLanguage.english);
      expect(newService.speechLocale, 'en_IN');
    });

    test('EmergencyStatus and Category translations are complete across all languages', () {
      for (final lang in AppLanguage.values) {
        final l10n = AppLocalizations(lang);
        for (final status in EmergencyStatus.values) {
          final translated = l10n.localizedEmergencyStatus(status);
          expect(translated.isNotEmpty, isTrue, reason: 'Status $status empty in $lang');
        }
        for (final cat in EmergencyCategory.values) {
          final translated = l10n.localizedEmergencyCategory(cat);
          expect(translated.isNotEmpty, isTrue, reason: 'Category $cat empty in $lang');
        }
      }
    });

    test('Voice-to-text strings are non-empty across all languages', () {
      for (final lang in AppLanguage.values) {
        final l10n = AppLocalizations(lang);
        expect(l10n.voiceInputHint.isNotEmpty, isTrue);
        expect(l10n.voiceListening.isNotEmpty, isTrue);
        expect(l10n.voiceConnecting.isNotEmpty, isTrue);
        expect(l10n.voicePermissionDenied.isNotEmpty, isTrue);
        expect(l10n.voiceRecognitionError.isNotEmpty, isTrue);
      }
    });
  });
}
