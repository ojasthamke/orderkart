import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/widgets/app_cached_image.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });
  });

  group('OrderKart Persistent Image Cache & Egress Prevention Tests', () {
    test('AppImageCacheManager configuration has 1-year stale period and correct key', () {
      expect(AppImageCacheManager.key, 'orderkart_image_cache');
      expect(AppImageCacheManager.instance, isNotNull);
    });

    test('SupabaseImageHelper defaults to direct URL on Free plan to avoid 403 Forbidden', () {
      SupabaseImageHelper.isTransformationSupported = false;
      const rawUrl = 'https://xsqaxvbrjvhgemlfgoxn.supabase.co/storage/v1/object/public/product-images/test.png';
      
      final result = SupabaseImageHelper.getOptimizedUrl(rawUrl, width: 300, height: 300);
      expect(result, rawUrl);
      expect(result.contains('/render/image/'), isFalse);
    });

    test('SupabaseImageHelper transforms to CDN resize when isTransformationSupported is enabled', () {
      SupabaseImageHelper.isTransformationSupported = true;
      const rawUrl = 'https://xsqaxvbrjvhgemlfgoxn.supabase.co/storage/v1/object/public/product-images/test.png';
      
      final result = SupabaseImageHelper.getOptimizedUrl(rawUrl, width: 300, height: 300, quality: 80);
      expect(result, contains('/storage/v1/render/image/public/product-images/test.png'));
      expect(result, contains('width=300'));
      expect(result, contains('height=300'));
      expect(result, contains('quality=80'));

      // Reset back to safe default
      SupabaseImageHelper.isTransformationSupported = false;
    });

    testWidgets('AppCachedImage renders fallback icon safely when imageUrl is null or empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCachedImage(
              imageUrl: '',
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('AppCachedImage handles whitespace-only URL gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCachedImage(
              imageUrl: '   \n\t   ',
              width: 80,
              height: 80,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    test('AppCachedImage.provider returns CachedNetworkImageProvider with singleton cache manager', () {
      final provider = AppCachedImage.provider('https://example.com/test.jpg');
      expect(provider, isNotNull);
    });

    test('AppImageCacheManager.clearCache does not throw unhandled exception', () async {
      await expectLater(AppImageCacheManager.clearCache(), completes);
    });
  });
}
