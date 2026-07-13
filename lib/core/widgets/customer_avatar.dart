import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import 'full_screen_image_viewer.dart';

class CustomerAvatar extends StatelessWidget {
  final String? photoPath;
  final double radius;

  const CustomerAvatar({
    super.key,
    required this.photoPath,
    this.radius = 24,
  });



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

    return GestureDetector(
      onTap: () {
        FullScreenImageViewer.show(
          context,
          AppConstants.resolveFile(photoPath!).path,
          isAsset: kIsWeb,
        );
      },
      child: ClipRRect(
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
                  AppConstants.resolveFile(photoPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => fallback,
                ),
        ),
      ),
    );
  }
}
