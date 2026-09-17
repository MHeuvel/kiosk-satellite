import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../managers/settings/definitions.dart';
import 'generated/message_lookup.dart';
import 'generated/navigation_ids.dart';
import 'generated/ui_strings.dart';

final _english = lookupUiStrings(const Locale('en'));

/// Standalone widgets and untranslated font locales use English messages.
UiStrings l10n(BuildContext context) => UiStrings.of(context) ?? _english;

String? localizeBaseUrlError(UiStrings strings, String? error) {
  final english = lookupUiStrings(const Locale('en'));
  if (error == english.baseUrlInvalid) return strings.baseUrlInvalid;
  if (error == english.baseUrlPath) return strings.baseUrlPath;
  if (error == english.baseUrlQuery) return strings.baseUrlQuery;
  return error;
}

/// Keep the framework locale for CJK glyphs while messages fall back separately.
class MessageDelegate extends LocalizationsDelegate<UiStrings> {
  const MessageDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<UiStrings> load(Locale locale) => SynchronousFuture(
    lookupUiStrings(
      basicLocaleListResolution([locale], UiStrings.supportedLocales),
    ),
  );

  @override
  bool shouldReload(MessageDelegate old) => false;
}

extension LocalizedSetting on SettingDef<Object> {
  String localizedTitle(BuildContext context) =>
      messageById(l10n(context), titleMessageId, title);

  String localizedDescription(BuildContext context) =>
      messageById(l10n(context), descriptionMessageId, description);
}

/// Translate menu presentation while keeping category and route keys stable.
String navigationText(BuildContext context, String english) =>
    messageById(l10n(context), navigationMessageIds[english], english);
