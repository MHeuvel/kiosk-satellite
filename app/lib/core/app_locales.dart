import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Localization setup for the root MaterialApp (issue #551).
///
/// Rubik has no CJK glyphs, so those characters fall back to system fonts.
/// The engine picks the fallback face by the locale it resolved for the
/// paragraph, and without delegates every device resolved to en_US, which
/// made a Japanese kiosk draw its clock and lyrics with Chinese-style
/// glyphs. CJK Unified Ideographs share code points across Chinese,
/// Japanese and Korean, so only the locale tells the font which shape to
/// use. Listing the CJK locales lets the device locale win that pick.
///
/// Devices in any other language resolve to English, the first entry, which
/// is what they got before. The HA dashboard renders in the WebView with
/// its own font and locale pipeline and is untouched by this.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Language-only entries catch generic device locales, the region and script
/// entries keep an exact match so zh-Hant-TW is not collapsed to zh.
const List<Locale> appSupportedLocales = [
  Locale('en'),
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
