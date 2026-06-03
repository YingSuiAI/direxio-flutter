import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_media_send_flow.dart';

typedef PickChatImages = Future<List<PickedChatImage>> Function();

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
      useIOSOrderedPicker: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
      pickOrderedIOSImages: const IOSOrderedImagePicker().pickImages,
      pickFallbackImages: () async {
        final files = await imagePicker.pickMultiImage();
        return files.map(PickedChatImage.fromXFile).toList(growable: false);
      },
    );
  }

  final bool useIOSOrderedPicker;
  final PickChatImages pickOrderedIOSImages;
  final PickChatImages pickFallbackImages;

  Future<List<ChatMediaAttachment>> pickImages() async {
    final images = useIOSOrderedPicker
        ? await _pickOrderedIOSImagesWithFallback()
        : await pickFallbackImages();
    final attachments = <ChatMediaAttachment>[];
    for (final image in images) {
      try {
        attachments.add(
          ChatMediaAttachment.image(
            name: image.name,
            bytes: await image.readAsBytes(),
            mimeType: image.mimeType.isEmpty ? 'image/jpeg' : image.mimeType,
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

  Future<List<PickedChatImage>> _pickOrderedIOSImagesWithFallback() async {
    try {
      return await pickOrderedIOSImages();
    } on MissingPluginException {
      return pickFallbackImages();
    } on PlatformException catch (error) {
      if (error.code == IOSOrderedImagePicker.unavailableCode) {
        return pickFallbackImages();
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

  Future<List<PickedChatImage>> pickImages() async {
    final values = await channel.invokeMethod<List<dynamic>>('pickOrderedImages');
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
      mimeType: mimeType is String && mimeType.isNotEmpty ? mimeType : 'image/jpeg',
    );
  }

  String _fileNameFromPath(String path) {
    final slash = path.lastIndexOf('/');
    return slash == -1 ? path : path.substring(slash + 1);
  }
}
