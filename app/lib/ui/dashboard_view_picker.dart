import 'package:flutter/material.dart';

import '../app_container.dart';
import 'kit.dart';

/// Every dashboard's views as (navigation path, "Dashboard / View") pairs,
/// flattened like the rotation picker. Strategy dashboards expose no views,
/// so their root stands in as one entry. Empty when Home Assistant cannot
/// list its dashboards.
Future<List<(String, String)>> listDashboardViewEntries(AppContainer c) async {
  final entries = <(String, String)>[];
  final dashboards = await c.commands.execute('haListDashboards', const {});
  if (!dashboards.ok || dashboards.data is! List) return entries;
  for (final d in dashboards.data as List) {
    if (d is! Map) continue;
    final urlPath = '${d['url_path'] ?? ''}';
    final title = '${d['title'] ?? urlPath}';
    if (urlPath.isEmpty) continue;
    final views = await c.commands.execute('haListDashboardViews', {
      'url_path': urlPath,
    });
    var added = false;
    if (views.ok && views.data is List) {
      for (final v in views.data as List) {
        if (v is! Map) continue;
        final route = '${v['route'] ?? ''}';
        if (route.isEmpty) continue;
        entries.add(('$urlPath/$route', '$title / ${v['title'] ?? route}'));
        added = true;
      }
    }
    if (!added) entries.add((urlPath, title));
  }
  return entries;
}

/// The dashboard view modal: the kit's radio picker, each view titled
/// "Dashboard / View" over its navigation path, as the Dashboard card's
/// "Change view" popup lists them. Resolves to the picked path, or null
/// when the dialog is dismissed.
Future<String?> showDashboardViewPicker(
  BuildContext context, {
  required String title,
  required List<(String, String)> entries,
  required String current,
}) => showRadioPicker<String>(
  context,
  title: title,
  selected: current,
  options: [
    for (final (path, label) in entries)
      PickerOption(path, label, detail: path),
  ],
);
