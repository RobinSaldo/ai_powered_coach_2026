import 'dart:convert';

import 'package:image_picker/image_picker.dart';

enum ProfilePhotoSource { gallery, camera }

class PickedProfilePhoto {
  const PickedProfilePhoto(this.base64);

  final String base64;
}

class ProfilePhotoService {
  ProfilePhotoService([ImagePicker? imagePicker])
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  static const int _maxRawBytes = 700 * 1024;

  Future<PickedProfilePhoto?> pickPhoto({
    required ProfilePhotoSource source,
  }) async {
    final picked = await _imagePicker.pickImage(
      source: source == ProfilePhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 45,
      maxWidth: 600,
      maxHeight: 600,
    );

    if (picked == null) {
      return null;
    }

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > _maxRawBytes) {
      throw const ProfilePhotoTooLargeException();
    }

    return PickedProfilePhoto(base64Encode(bytes));
  }
}

class ProfilePhotoTooLargeException implements Exception {
  const ProfilePhotoTooLargeException();
}
