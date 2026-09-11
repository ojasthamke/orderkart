import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Central singleton cache manager for OrderKart.
/// Retains images on local device flash/disk storage for 365 days,
/// ensuring 0 bytes of network transfer on subsequent views or app launches.
class AppImageCacheManager {
  AppImageCacheManager._();

  static const String key = 'orderkart_image_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 365), // 1-year disk retention
      maxNrOfCacheObjects: 2000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  /// Empty all cached images from disk.
  static Future<void> clearCache() async {
    try {
      await instance.emptyCache();
    } catch (_) {}
  }
}

/// Helper for Supabase storage image URLs and CDN optimizations.
class SupabaseImageHelper {
  SupabaseImageHelper._();

  static bool isTransformationSupported = false;

  static String getOptimizedUrl(String? url, {int? width, int? height, int quality = 75}) {
    if (url == null || url.trim().isEmpty) return '';
    final cleanUrl = url.trim().replaceAll(' ', '%20');

    if (isTransformationSupported && (width != null || height != null)) {
      if (cleanUrl.contains('/storage/v1/object/public/')) {
        final transformed = cleanUrl.replaceFirst(
          '/storage/v1/object/public/',
          '/storage/v1/render/image/public/',
        );
        final queryParams = <String>[];
        if (width != null) queryParams.add('width=$width');
        if (height != null) queryParams.add('height=$height');
        queryParams.add('quality=$quality');
        final separator = transformed.contains('?') ? '&' : '?';
        return '$transformed$separator${queryParams.join('&')}';
      }
    }
    return cleanUrl;
  }
}

/// Production-grade cached image widget for OrderKart.
class AppCachedImage extends StatelessWidget {
  final String? imageUrl;
  final String? cacheKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Color? fallbackColor;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth = 360,
    this.memCacheHeight,
    this.fallbackColor,
    this.fallbackIcon = Icons.image_not_supported_outlined,
    this.fallbackIconSize = 24,
  });

  /// Returns a cached ImageProvider using the persistent disk cache manager.
  static ImageProvider provider(String url, {int? maxHeight, int? maxWidth}) {
    return CachedNetworkImageProvider(
      url,
      cacheManager: AppImageCacheManager.instance,
      maxHeight: maxHeight,
      maxWidth: maxWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sanitizedUrl = (imageUrl ?? '').trim();

    Widget fallback = errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fallbackColor ?? const Color(0xFFF1F5F9),
            borderRadius: borderRadius,
          ),
          alignment: Alignment.center,
          child: Icon(
            fallbackIcon,
            size: fallbackIconSize,
            color: const Color(0xFF64748B),
          ),
        );

    if (sanitizedUrl.isEmpty) {
      return borderRadius != null
          ? ClipRRect(borderRadius: borderRadius!, child: fallback)
          : fallback;
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: sanitizedUrl,
      cacheKey: cacheKey ?? sanitizedUrl,
      cacheManager: AppImageCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
              borderRadius: borderRadius,
            ),
          ),
      errorWidget: (context, url, error) => fallback,
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
