import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _saveImageToGalleryChannel = MethodChannel('p2p_im/save_image');

class SaveImageToGalleryException implements Exception {
  const SaveImageToGalleryException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<void> savePngImageToGallery({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (kIsWeb) {
    throw const SaveImageToGalleryException(
        'Web does not support saving to the phone album.');
  }
  if (bytes.isEmpty) {
    throw const SaveImageToGalleryException('Image data is empty.');
  }

  await _saveImageToGalleryChannel.invokeMethod<void>('savePng', {
    'bytes': bytes,
    'fileName': fileName,
  });
}

Future<void> saveMediaFileToGallery({
  required String path,
  required String fileName,
  required String mimeType,
}) async {
  if (kIsWeb) {
    throw const SaveImageToGalleryException(
        'Web does not support saving to the phone album.');
  }
  if (path.trim().isEmpty) {
    throw const SaveImageToGalleryException('Media path is empty.');
  }
  if (fileName.trim().isEmpty) {
    throw const SaveImageToGalleryException('Media file name is empty.');
  }
  if (mimeType.trim().isEmpty) {
    throw const SaveImageToGalleryException('Media MIME type is empty.');
  }

  await _saveImageToGalleryChannel.invokeMethod<void>('saveMediaFile', {
    'path': path,
    'fileName': fileName,
    'mimeType': mimeType,
  });
}
