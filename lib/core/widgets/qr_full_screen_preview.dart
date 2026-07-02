import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrFullScreenPreview extends StatelessWidget {
  final String? qrCustomImage;
  final String? qrContent;

  const QrFullScreenPreview({super.key, this.qrCustomImage, this.qrContent});

  static void show(BuildContext context, {String? qrCustomImage, String? qrContent}) {
    showDialog(
      context: context,
      builder: (_) => QrFullScreenPreview(
        qrCustomImage: qrCustomImage,
        qrContent: qrContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: qrCustomImage != null && qrCustomImage!.isNotEmpty
                  ? Image.file(
                      File(qrCustomImage!),
                      fit: BoxFit.contain,
                    )
                  : QrImageView(
                      data: qrContent ?? '',
                      version: QrVersions.auto,
                      size: 300.0,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
