import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  static const double maxWidth = 800;
  static const double maxHeight = 800;
  static const int imageQuality = 70;

  /// Pick an image from camera or gallery and apply native compression.
  static Future<XFile?> pickAndCompress({
    required ImageSource source,
  }) async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  /// Copies an image file permanently to the specified app documents subdirectory.
  /// Automatically cleans up the original temporary cache file.
  static Future<String?> saveImagePermanently({
    required String sourcePath,
    required String subFolder,
    required String fileName,
  }) async {
    if (sourcePath.isEmpty) return null;

    try {
      final file = File(sourcePath);
      if (!file.existsSync()) return null;

      final docsDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(docsDir.path, subFolder));
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      // If it is already in the target directory, don't copy again
      if (p.isWithin(targetDir.path, sourcePath)) {
        return sourcePath;
      }

      final ext = p.extension(sourcePath);
      final destFile = File(p.join(targetDir.path, '$fileName$ext'));

      // Copy to destination
      await file.copy(destFile.path);

      // Clean up original temporary cache file
      await clearImagePickerCache();

      return destFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Clears temporary cache files left by the image picker in the cache directory
  static Future<void> clearImagePickerCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final list = tempDir.listSync();
        for (final file in list) {
          if (file is File) {
            final name = p.basename(file.path).toLowerCase();
            if (name.contains('image_picker')) {
              try {
                await file.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
  }
}
