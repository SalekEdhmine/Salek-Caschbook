// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void downloadBytes(List<int> bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url  = html.Url.createObjectUrlFromBlob(blob);
  final a    = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}
