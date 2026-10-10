import 'dart:math';
import 'dart:typed_data';

/// Same limit as the web portal's credential upload rule (`max:10240` KB).
const int maxUploadBytes = 10 * 1024 * 1024;

/// Extensions the in-app file viewer can display and HR can review.
const List<String> allowedUploadExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

class ValidatedUpload {
  const ValidatedUpload({
    required this.extension,
    required this.contentType,
    required this.storedFileName,
    required this.displayFileName,
  });

  /// Extension implied by the file's actual content, not by its name.
  final String extension;
  final String contentType;

  /// Server-style random name used as the storage object key, like the web
  /// portal's `time() . '_' . bin2hex(random_bytes(4)) . '.' . ext`.
  final String storedFileName;

  /// Sanitized original name, only for display in `original_filename`.
  final String displayFileName;
}

class UploadValidationException implements Exception {
  const UploadValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Validates an upload by size, extension AND magic bytes. Throws
/// [UploadValidationException] with a user-safe message when rejected.
ValidatedUpload validateUpload({
  required String originalName,
  required Uint8List bytes,
  Random? random,
  DateTime? now,
}) {
  if (bytes.isEmpty) {
    throw const UploadValidationException('The selected file is empty.');
  }
  if (bytes.length > maxUploadBytes) {
    throw const UploadValidationException(
      'The file is too large. The maximum size is 10 MB.',
    );
  }

  final name = originalName.trim();
  final dot = name.lastIndexOf('.');
  final declaredExt =
      dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (!allowedUploadExtensions.contains(declaredExt)) {
    throw const UploadValidationException(
      'Only PDF, JPG and PNG files can be uploaded.',
    );
  }

  final detected = _detectType(bytes);
  if (detected == null) {
    throw const UploadValidationException(
      'The file content is not a valid PDF, JPG or PNG file.',
    );
  }
  final declaredKind = declaredExt == 'jpeg' ? 'jpg' : declaredExt;
  if (declaredKind != detected.$1) {
    throw const UploadValidationException(
      'The file extension does not match its content.',
    );
  }

  final rng = random ?? Random.secure();
  final suffix = List.generate(
    4,
    (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;

  var display = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  if (display.length > 120) {
    display = display.substring(display.length - 120);
  }

  return ValidatedUpload(
    extension: detected.$1,
    contentType: detected.$2,
    storedFileName: '${seconds}_$suffix.${detected.$1}',
    displayFileName: display,
  );
}

(String, String)? _detectType(Uint8List b) {
  bool startsWith(List<int> sig) {
    if (b.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[i] != sig[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0x25, 0x50, 0x44, 0x46, 0x2D])) {
    return ('pdf', 'application/pdf'); // %PDF-
  }
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return ('png', 'image/png');
  }
  if (startsWith(const [0xFF, 0xD8, 0xFF])) {
    return ('jpg', 'image/jpeg');
  }
  return null;
}
