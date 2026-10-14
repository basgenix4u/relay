// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveBytes(Uint8List bytes, String name, String mime) async {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = name;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future.delayed(
      const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
}
