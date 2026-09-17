import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../managers/settings/definitions.dart';
import 'generated/message_lookup.dart';
import 'generated/navigation_ids.dart';
import 'generated/device_text_ids.dart';
import 'generated/ha_text_ids.dart';
import 'generated/screensaver_text_ids.dart';
import 'generated/camera_text_ids.dart';
import 'generated/camera_streams_text_ids.dart';
import 'generated/screen_audio_text_ids.dart';
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

/// Resolve fixed Home Assistant settings wording, never supplied names or paths.
String haText(BuildContext context, String english) =>
    messageById(l10n(context), haTextMessageIds[english], english);

/// Resolve Screen & Audio wording while keeping hardware names unchanged.
String screenAudioText(BuildContext context, String english) =>
    messageById(l10n(context), screenAudioTextMessageIds[english], english);

/// Resolve fixed screensaver wording without translating supplied values.
String screensaverText(BuildContext context, String english) =>
    messageById(l10n(context), screensaverTextMessageIds[english], english);

/// Resolve camera presentation while preserving addresses and hardware names.
String cameraText(BuildContext context, String english) =>
    messageById(l10n(context), cameraTextMessageIds[english], english);

String cameraStreamsText(BuildContext context, String english) =>
    messageById(l10n(context), cameraStreamsTextMessageIds[english], english);

String cameraStreamsError(BuildContext context, String error) {
  final http = RegExp(r'^Go2RTC returned HTTP (\d+)$').firstMatch(error);
  if (http != null) return l10n(context).cameraStreamsHttpError(http[1]!);
  const haPrefix = 'could not read Home Assistant: ';
  if (error.startsWith(haPrefix)) {
    return l10n(
      context,
    ).cameraStreamsHaReadFailed(error.substring(haPrefix.length));
  }
  final connection = RegExp(
    r'^could not connect to (.+?): (.*)$',
    dotAll: true,
  ).firstMatch(error);
  if (connection != null) {
    return l10n(
      context,
    ).cameraStreamsConnectFailed(connection[1]!, connection[2]!);
  }
  return cameraStreamsText(context, error);
}

String cameraError(BuildContext context, String error) =>
    error.startsWith('Snapshot failed: ')
    ? l10n(
        context,
      ).cameraSnapshotError(error.substring('Snapshot failed: '.length))
    : cameraText(context, error);

String cameraResolutionNotice(BuildContext context, String notice) {
  final strings = l10n(context);
  notice = notice.replaceAll(
    'Motion detection, face detection and hand gestures pause while viewers are connected. Snapshots use video frames at the streaming resolution.',
    strings.cameraAnalysisOff,
  );
  return notice
      .split(RegExp(r'(?<=\.) '))
      .map((part) {
        final extra = RegExp(
          r'^Turn off Motion analysis while streaming to also use (.+)\.$',
        ).firstMatch(part);
        if (extra != null) return strings.cameraExtraSizes(extra[1]!);
        final rejected = RegExp(
          r'^The encoder cannot use (.+) at these settings\.$',
        ).firstMatch(part);
        if (rejected != null) return strings.cameraRejectedSizes(rejected[1]!);
        final count = RegExp(
          r'^(\d+) camera sizes are excluded because the encoder cannot use them at these settings\.$',
        ).firstMatch(part);
        if (count != null) return strings.cameraRejectedCount(count[1]!);
        return cameraText(context, part);
      })
      .join(' ');
}

String screensaverError(BuildContext context, String error) {
  final match = RegExp(r'^Use at most ([0-9]+) characters$').firstMatch(error);
  return match == null
      ? screensaverText(context, error)
      : l10n(context).screensaverMaxCharacters(match[1]!);
}

String settingsPageText(
  BuildContext context,
  String category,
  String english,
) => switch (category) {
  'Device' => deviceText(context, english),
  'Home Assistant' => haText(context, english),
  'Screen & Audio' => screenAudioText(context, english),
  'Screensaver' => screensaverText(context, english),
  'Camera' => cameraText(context, english),
  _ => english,
};

String haConnectionError(BuildContext context, String error) =>
    error.startsWith('unreachable: ')
    ? l10n(context).haUnreachable(error.substring('unreachable: '.length))
    : haText(context, error);

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

String commonColorName(BuildContext context, String english) =>
    switch (english) {
      'White' => l10n(context).commonColorWhite,
      'Warm' => l10n(context).commonColorWarm,
      'Amber' => l10n(context).commonColorAmber,
      'Red' => l10n(context).commonColorRed,
      'Green' => l10n(context).commonColorGreen,
      'Blue' => l10n(context).commonColorBlue,
      'Cyan' => l10n(context).commonColorCyan,
      'Dim' => l10n(context).commonColorDim,
      _ => english,
    };

String immichError(BuildContext context, String error) {
  final strings = l10n(context);
  final scope = RegExp(
    r'^The API key is missing the (.+) permission\.$',
  ).firstMatch(error);
  if (scope != null) return strings.screensaverMediaScopeMissing(scope[1]!);
  const permission = 'The API key is missing a permission: ';
  if (error.startsWith(permission)) {
    return strings.screensaverMediaPermissionMissing(
      error.substring(permission.length),
    );
  }
  final status = RegExp(
    r'^The server answered ([0-9]+): ([\s\S]*)$',
  ).firstMatch(error);
  if (status != null) {
    return strings.screensaverMediaServerError(status[1]!, status[2]!);
  }
  final url = RegExp(r'^Could not reach ([\s\S]+)\.$').firstMatch(error);
  if (url != null) return strings.screensaverMediaUnreachable(url[1]!);
  const talk = 'Could not talk to the server: ';
  if (error.startsWith(talk)) {
    return strings.screensaverMediaTalkError(error.substring(talk.length));
  }
  return screensaverText(context, error);
}
