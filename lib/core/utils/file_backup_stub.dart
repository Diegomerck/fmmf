import 'dart:typed_data';

class PickedFileResult {
  final String name;
  final Uint8List bytes;
  final String? text;

  const PickedFileResult({
    required this.name,
    required this.bytes,
    this.text,
  });
}

Future<void> downloadJsonFile(String filename, String content) async {
  // Non-web platforms: no-op fallback
}

Future<String?> pickJsonFileContent() async {
  return null;
}

Future<String?> pickTextFileContent({String accept = '.csv,.txt'}) async {
  return null;
}

Future<PickedFileResult?> pickStatementFile({String accept = '.pdf,.csv,.txt'}) async {
  return null;
}

void Function() registerStatementDropListener({
  required void Function(bool isHovering) onHoverChanged,
  required void Function(PickedFileResult file) onFileDropped,
  void Function(String message)? onError,
}) {
  return () {};
}
