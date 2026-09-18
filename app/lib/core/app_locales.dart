import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/generated/ui_strings.dart';
import '../l10n/messages.dart';

/// English is the default until automatic language selection is offered.
Locale appLocaleForLanguage(String language) {
  for (final locale in UiStrings.supportedLocales) {
    if (locale.toLanguageTag() == language) return locale;
  }
  return const Locale('en');
}

/// Preserve regional CJK glyphs when the interface uses a non-CJK language.
/// Rubik falls back to system fonts for CJK text, including device-language
/// dates and media titles. Those fonts use the paragraph locale to select
/// regional character shapes (#551, #601). The HA WebView is independent.
Locale appRenderingLocale(Locale uiLocale, List<Locale> deviceLocales) {
  const cjk = {'ja', 'ko', 'zh'};
  if (!cjk.contains(uiLocale.languageCode) &&
      deviceLocales.isNotEmpty &&
      cjk.contains(deviceLocales.first.languageCode)) {
    return basicLocaleListResolution([
      deviceLocales.first,
    ], appSupportedLocales);
  }
  return uiLocale;
}

/// Defaults for widgets that follow the inherited locale.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  MessageDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The root app chooses messages separately from the rendering locale.
/// Bind all resources to the selected language so Flutter controls and text
/// direction follow it too. Reload even when the CJK rendering locale stays
/// the same during a live language change.
List<LocalizationsDelegate<dynamic>> appLocalizationsForUiLocale(
  Locale locale,
) => [
  _UiLocaleDelegate<UiStrings>(const MessageDelegate(), locale),
  _UiLocaleDelegate<MaterialLocalizations>(
    GlobalMaterialLocalizations.delegate,
    locale,
  ),
  _UiLocaleDelegate<WidgetsLocalizations>(
    GlobalWidgetsLocalizations.delegate,
    locale,
  ),
  _UiLocaleDelegate<CupertinoLocalizations>(
    GlobalCupertinoLocalizations.delegate,
    locale,
  ),
];

class _UiLocaleDelegate<T> extends LocalizationsDelegate<T> {
  const _UiLocaleDelegate(this.delegate, this.uiLocale);

  final LocalizationsDelegate<T> delegate;
  final Locale uiLocale;

  @override
  bool isSupported(Locale locale) => delegate.isSupported(uiLocale);

  @override
  Future<T> load(Locale locale) => delegate.load(uiLocale);

  @override
  bool shouldReload(_UiLocaleDelegate<T> old) =>
      uiLocale != old.uiLocale || delegate.shouldReload(old.delegate);
}

/// Language-only entries catch generic device locales, the region and script
/// entries keep an exact match so zh-Hant-TW is not collapsed to zh.
const List<Locale> appSupportedLocales = [
  ...UiStrings.supportedLocales,
  Locale('ja'),
  Locale('ja', 'JP'),
  Locale('ko'),
  Locale('ko', 'KR'),
  Locale('zh'),
  Locale('zh', 'CN'),
  Locale('zh', 'TW'),
  Locale('zh', 'HK'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK'),
];
