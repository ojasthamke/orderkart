import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import 'package:path/path.dart' as p;

class CustomerAvatar extends StatelessWidget {
  final String? photoPath;
  final double radius;

  const CustomerAvatar({
    super.key,
    required this.photoPath,
    this.radius = 24,
  });

  File _resolveFile(String originalPath) {
    final file = File(originalPath);
    if (file.existsSync()) return file;
    
    // Check fallback folder if we have appDocsDir
    if (AppConstants.appDocsDir.isNotEmpty) {
      final filename = p.basename(originalPath);
      final fallbackFile = File('${AppConstants.appDocsDir}/customer_photos/$filename');
      if (fallbackFile.existsSync()) {
        return fallbackFile;
      }
    }
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && photoPath!.isNotEmpty;
    final size = radius * 2;

    Widget fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primarySurface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        size: radius,
        color: AppColors.primary,
      ),
    );

    if (!hasPhoto) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: kIsWeb
            ? Image.network(
                photoPath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : Image.file(
                _resolveFile(photoPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}
