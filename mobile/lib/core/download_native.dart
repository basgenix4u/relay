import 'dart:typed_data';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';

Future<void> saveBytes(Uint8List bytes, String name, String mime) async {
  await Share.shareXFiles([XFile.fromData(bytes, mimeType: mime, name: name)],
      subject: name, sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1));
}
