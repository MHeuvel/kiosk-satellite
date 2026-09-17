import 'package:flutter/material.dart';

import 'kit.dart';
import '../l10n/messages.dart';

/// What a configuration import should do about the two things a backup
/// carries that belong to one specific device (issue #25): its identity
/// (device name + ESPHome node name) and its page data (which includes the
/// Voice Satellite selection).
typedef ImportOptions = ({bool adoptIdentity, bool importLocalStorage});

/// Ask the two import questions. Returns null when cancelled.
///
/// The defaults track the choice: replacing the original device pulls its
/// dashboard data along, a new device starts with its own, and a touched
/// checkbox stops following.
Future<ImportOptions?> showImportOptionsDialog(
  BuildContext context, {
  String? backupDeviceName,
}) {
  var adopt = false;
  var local = false;
  var localTouched = false;
  final replaceLabel =
      (backupDeviceName == null || backupDeviceName.trim().isEmpty)
      ? deviceText(context, 'Replace the original device')
      : l10n(context).deviceReplaceNamed(backupDeviceName.trim());
  return showDialog<ImportOptions>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(deviceText(context, 'Import configuration')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deviceText(
                  context,
                  "Replace this device's settings with the file's? The page "
                  'may reload.',
                ),
              ),
              SizedBox(height: 16),
              ScrollingSegments(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(deviceText(context, 'Set up as new device')),
                    ),
                    ButtonSegment(value: true, label: Text(replaceLabel)),
                  ],
                  selected: {adopt},
                  onSelectionChanged: (selection) => setState(() {
                    adopt = selection.first;
                    if (!localTouched) local = adopt;
                  }),
                ),
              ),
              SizedBox(height: 4),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  adopt
                      ? deviceText(
                          context,
                          'Keeps the backup\'s name and ESPHome identity; the '
                          'original device must stay offline.',
                        )
                      : deviceText(
                          context,
                          'Assign its own name and ESPHome identity, so both '
                          'devices are unique.',
                        ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: local,
                onChanged: (v) => setState(() {
                  local = v == true;
                  localTouched = true;
                }),
                title: Text(
                  deviceText(context, "Restore Webview's local storage"),
                ),
                subtitle: Text(
                  deviceText(
                    context,
                    'Includes the Home Assistant signed in session and the '
                    'Voice Satellite assist_satellite selection - two devices '
                    'must not share one satellite.',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(deviceText(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              adoptIdentity: adopt,
              importLocalStorage: local,
            )),
            child: Text(deviceText(context, 'Import')),
          ),
        ],
      ),
    ),
  );
}
