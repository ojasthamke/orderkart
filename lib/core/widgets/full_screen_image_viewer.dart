import 'dart:io';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  final bool isAsset;
  final String? title;

  const FullScreenImageViewer({
    Key? key,
    required this.imagePath,
    this.isAsset = false,
    this.title,
  }) : super(key: key);

  static void show(
    BuildContext context,
    String imagePath, {
    bool isAsset = false,
    String? title,
  }) {
    if (imagePath.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => FullScreenImageViewer(
          imagePath: imagePath,
          isAsset: isAsset,
          title: title,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if (isAsset) {
      imageProvider = AssetImage(imagePath);
    } else {
      imageProvider = FileImage(File(imagePath));
    }

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive viewer for pinch-to-zoom and pan
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: imagePath,
                  child: Image(
                    image: imageProvider,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_rounded,
                                size: 64, color: Colors.white54),
                            SizedBox(height: 12),
                            Text(
                              'Unable to load image',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Header bar with optional Title and Close Button
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title if provided
                  Expanded(
                    child: title != null
                        ? Text(
                            title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black54,
                                  offset: Offset(1.0, 1.0),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Close button container
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
