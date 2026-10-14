import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'api.dart';

Future<int> saveToDevice(Api api, {List<int>? ids, int? groupId}) async {
  if (kIsWeb) {
    throw ApiException(
        'Use the vCard export in the browser. Direct address-book saving is available on Android and iOS.',
        0);
  }
  if (!await fc.FlutterContacts.requestPermission()) {
    throw ApiException(
        'Contacts permission was not granted. You can still export a vCard file.',
        0);
  }
  final result = await api.get('/contacts', {
    'limit': '5000',
    if (ids != null && ids.isNotEmpty) 'ids': ids.join(','),
    if (groupId != null) 'group_id': '$groupId'
  });
  final rows = (result['items'] as List)
      .where((c) =>
          c['is_demo'] != true &&
          (ids == null || ids.isEmpty || ids.contains(c['id'])))
      .toList();
  final existing = await fc.FlutterContacts.getContacts(withProperties: true);
  final phones = existing
      .expand((c) => c.phones)
      .map((p) => p.number.replaceAll(RegExp(r'[^\d]'), ''))
      .toSet();
  var added = 0;
  for (final row in rows) {
    final normalized =
        (row['phone'] as String).replaceAll(RegExp(r'[^\d]'), '');
    if (phones.contains(normalized)) continue;
    final contact = fc.Contact()
      ..name = fc.Name(first: row['first_name'], last: row['last_name'])
      ..phones = [fc.Phone(row['phone'])];
    if ((row['email'] as String).isNotEmpty) {
      contact.emails = [fc.Email(row['email'])];
    }
    await contact.insert();
    phones.add(normalized);
    added++;
  }
  return added;
}
