import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_media_send_flow.dart';

const chatImagePickerMaxSelection = 9;
const chatImagePickerCompressedMaxDimension = 1600.0;
const chatImagePickerCompressedQuality = 78;

typedef PickChatImages = Future<List<PickedChatImage>> Function({
  required bool original,
  required int limit,
});

class PickedChatImage {
  const PickedChatImage({
    required this.name,
    required this.mimeType,
    required this.readAsBytes,
  });

  factory PickedChatImage.fromXFile(XFile file) {
    return PickedChatImage(
      name: file.name,
      mimeType: file.mimeType ?? 'image/jpeg',
      readAsBytes: file.readAsBytes,
    );
  }

  final String name;
  final String mimeType;
  final Future<Uint8List> Function() readAsBytes;
}

class ChatImageAttachmentPicker {
  const ChatImageAttachmentPicker({
    required this.useIOSOrderedPicker,
    required this.pickOrderedIOSImages,
    required this.pickFallbackImages,
  });

  factory ChatImageAttachmentPicker.platform() {
    final imagePicker = ImagePicker();
    return ChatImageAttachmentPicker(
      useIOSOrderedPicker:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
      pickOrderedIOSImages: const IOSOrderedImagePicker().pickImages,
      pickFallbackImages: ({required original, required limit}) async {
        final files = await imagePicker.pickMultiImage(
          maxWidth: original ? null : chatImagePickerCompressedMaxDimension,
          maxHeight: original ? null : chatImagePickerCompressedMaxDimension,
          imageQuality: original ? null : chatImagePickerCompressedQuality,
          limit: limit,
        );
        return files.map(PickedChatImage.fromXFile).toList(growable: false);
      },
    );
  }

  final bool useIOSOrderedPicker;
  final PickChatImages pickOrderedIOSImages;
  final PickChatImages pickFallbackImages;

  Future<List<ChatMediaAttachment>> pickImages({
    bool original = false,
    int limit = chatImagePickerMaxSelection,
  }) async {
    final cappedLimit = limit.clamp(1, chatImagePickerMaxSelection).toInt();
    final images = useIOSOrderedPicker
        ? await _pickOrderedIOSImagesWithFallback(
            original: original,
            limit: cappedLimit,
          )
        : await pickFallbackImages(original: original, limit: cappedLimit);
    final attachments = <ChatMediaAttachment>[];
    for (final image in images.take(cappedLimit)) {
      try {
        attachments.add(
          ChatMediaAttachment.image(
            name: image.name,
            bytes: await image.readAsBytes(),
            mimeType: image.mimeType.isEmpty ? 'image/jpeg' : image.mimeType,
            original: original,
          ),
        );
      } on Object catch (error, stackTrace) {
        throw ChatMediaSendException(
          ChatMediaSendStage.read,
          error,
          stackTrace,
          label: '图片',
        );
      }
    }
    return attachments;
  }

  Future<List<PickedChatImage>> _pickOrderedIOSImagesWithFallback({
    required bool original,
    required int limit,
  }) async {
    try {
      return await pickOrderedIOSImages(original: original, limit: limit);
    } on MissingPluginException {
      return pickFallbackImages(original: original, limit: limit);
    } on PlatformException catch (error) {
      if (error.code == IOSOrderedImagePicker.unavailableCode) {
        return pickFallbackImages(original: original, limit: limit);
      }
      rethrow;
    }
  }
}

class IOSOrderedImagePicker {
  const IOSOrderedImagePicker([
    this.channel = const MethodChannel('p2p_im/ordered_image_picker'),
  ]);

  static const unavailableCode = 'ordered_picker_unavailable';

  final MethodChannel channel;

  Future<List<PickedChatImage>> pickImages({
    required bool original,
    required int limit,
  }) async {
    final values = await channel.invokeMethod<List<dynamic>>(
      'pickOrderedImages',
      {'original': original, 'limit': limit},
    );
    return (values ?? const <dynamic>[])
        .map((value) => PickedChatImage.fromXFile(_xFileFromNativeValue(value)))
        .toList(growable: false);
  }

  XFile _xFileFromNativeValue(Object? value) {
    if (value is! Map) {
      throw StateError('Invalid ordered image picker result: $value');
    }
    final path = value['path'];
    if (path is! String || path.isEmpty) {
      throw StateError('Ordered image picker result is missing a file path');
    }
    final name = value['name'];
    final mimeType = value['mimeType'];
    return XFile(
      path,
      name: name is String && name.isNotEmpty ? name : _fileNameFromPath(path),
      mimeType:
          mimeType is String && mimeType.isNotEmpty ? mimeType : 'image/jpeg',
    );
  }

  String _fileNameFromPath(String path) {
    final slash = path.lastIndexOf('/');
    return slash == -1 ? path : path.substring(slash + 1);
  }
}
