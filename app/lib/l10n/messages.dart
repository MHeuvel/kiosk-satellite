import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../managers/settings/definitions.dart';
import 'generated/message_lookup.dart';
import 'generated/navigation_ids.dart';
import 'generated/device_text_ids.dart';
import 'generated/setting_option_ids.dart';
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

/// Resolve fixed Device page wording without translating supplied values.
String deviceText(BuildContext context, String english) =>
    messageById(l10n(context), deviceTextMessageIds[english], english);

extension LocalizedSettingChoices on SettingDef<Object> {
  String localizedOption(BuildContext context, String value, String fallback) =>
      messageById(
        l10n(context),
        settingOptionMessageIds[key]?[value],
        fallback,
      );
  String? localizedPlaceholder(BuildContext context) => placeholder == null
      ? null
      : messageById(
          l10n(context),
          settingPlaceholderMessageIds[key],
          placeholder!,
        );
}

String localizedRemoteReason(BuildContext context, String reason) {
  final match = RegExp(
    r'^Could not listen on port ([0-9]+): ([\s\S]*)$',
  ).firstMatch(reason);
  return match == null
      ? deviceText(context, reason)
      : l10n(context).devicePortError(match[1]!, match[2]!);
}
