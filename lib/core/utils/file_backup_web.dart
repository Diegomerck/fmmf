// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
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
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'application/json;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<String?> pickJsonFileContent() async {
  return pickTextFileContent(accept: '.json,application/json');
}

Future<String?> pickTextFileContent({String accept = '.csv,.txt'}) async {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = accept;
  input.onChange.listen((_) {
    final file = input.files?.first;
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(reader.result as String?);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsText(file);
  });
  input.click();
  return completer.future;
}

Future<PickedFileResult?> pickStatementFile({String accept = '.pdf,.csv,.txt'}) async {
  final completer = Completer<PickedFileResult?>();
  final input = html.FileUploadInputElement()..accept = accept;
  input.onChange.listen((_) {
    final file = input.files?.first;
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (!completer.isCompleted) {
        final res = reader.result;
        if (res is Uint8List) {
          String? text;
          if (!file.name.toLowerCase().endsWith('.pdf')) {
            text = utf8.decode(res, allowMalformed: true);
          }
          completer.complete(PickedFileResult(name: file.name, bytes: res, text: text));
        } else if (res is ByteBuffer) {
          final bytes = res.asUint8List();
          String? text;
          if (!file.name.toLowerCase().endsWith('.pdf')) {
            text = utf8.decode(bytes, allowMalformed: true);
          }
          completer.complete(PickedFileResult(name: file.name, bytes: bytes, text: text));
        } else {
          completer.complete(null);
        }
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsArrayBuffer(file);
  });
  input.click();
  return completer.future;
}

void Function() registerStatementDropListener({
  required void Function(bool isHovering) onHoverChanged,
  required void Function(PickedFileResult file) onFileDropped,
  void Function(String message)? onError,
}) {
  final subs = <StreamSubscription<dynamic>>[];

  subs.add(html.window.onDragOver.listen((event) {
    event.preventDefault();
    event.stopPropagation();
    onHoverChanged(true);
  }));

  subs.add(html.window.onDragLeave.listen((event) {
    event.preventDefault();
    onHoverChanged(false);
  }));

  subs.add(html.window.onDrop.listen((event) {
    event.preventDefault();
    event.stopPropagation();
    onHoverChanged(false);

    final files = event.dataTransfer.files;
    if (files == null || files.isEmpty) return;
    final file = files.first;
    final lower = file.name.toLowerCase();
    if (!lower.endsWith('.pdf') && !lower.endsWith('.csv') && !lower.endsWith('.txt')) {
      onError?.call('Formato no soportado. Usa .pdf, .csv o .txt');
      return;
    }

    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final res = reader.result;
      Uint8List? bytes;
      if (res is Uint8List) {
        bytes = res;
      } else if (res is ByteBuffer) {
        bytes = res.asUint8List();
      }
      if (bytes == null) {
        onError?.call('No se pudo leer el archivo ${file.name}');
        return;
      }
      final text = lower.endsWith('.pdf') ? null : utf8.decode(bytes, allowMalformed: true);
      onFileDropped(PickedFileResult(name: file.name, bytes: bytes, text: text));
    });
    reader.onError.listen((_) {
      onError?.call('Error al leer el archivo ${file.name}');
    });
    reader.readAsArrayBuffer(file);
  }));

  return () {
    for (final s in subs) {
      s.cancel();
    }
  };
}
