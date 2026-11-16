import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/chat_repository.dart';

Future<PickedImage?> pickChatImage(ImageSource source, {double maxSize = 1600}) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: maxSize,
    maxHeight: maxSize,
    imageQuality: 80,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  final decoded = await decodeImageFromList(bytes);
  final name = file.name.toLowerCase();
  var contentType = file.mimeType ?? '';
  if (!contentType.startsWith('image/')) {
    contentType = name.endsWith('.png') ? 'image/png' : 'image/jpeg';
  }
  final picked = PickedImage(
    bytes: bytes,
    contentType: contentType,
    width: decoded.width,
    height: decoded.height,
  );
  decoded.dispose();
  return picked;
}

Future<ImageSource?> askImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, size: 32),
              title: const Text('รูปภาพจากคลัง', style: TextStyle(fontSize: 20)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, size: 32),
              title: const Text('ถ่ายรูป', style: TextStyle(fontSize: 20)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
}
