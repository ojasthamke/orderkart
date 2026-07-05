// test/security_helper_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:orderkart/core/utils/security_helper.dart';

void main() {
  group('SecurityHelper HMAC Tests', () {
    test('generateOwnerSecret returns a valid base64url string', () {
      final secret = SecurityHelper.generateOwnerSecret();
      expect(secret, isNotEmpty);
      // Base64Url 32 bytes should be at least 43 characters
      expect(secret.length, greaterThanOrEqualTo(43));
    });

    test('signManifest generates a valid signature', () {
      final manifest = {
        'package_id': 'test-package-123',
        'db_version': '4',
        'schema_version': '4',
        'export_timestamp': '2026-07-05T12:00:00Z',
      };
      final secret = 'test-owner-secret-key-1234567890';
      
      final signature = SecurityHelper.signManifest(manifest, secret);
      expect(signature, isNotEmpty);
      expect(signature.length, equals(64)); // SHA-256 hex is 64 characters
    });

    test('verifyManifest validates signature successfully', () {
      final manifest = {
        'package_id': 'test-package-123',
        'db_version': '4',
        'schema_version': '4',
        'export_timestamp': '2026-07-05T12:00:00Z',
        'signature': '', // signature field exists but will be stripped during signing
      };
      final secret = 'test-owner-secret-key-1234567890';
      
      final signature = SecurityHelper.signManifest(manifest, secret);
      final manifestWithSig = Map<String, dynamic>.from(manifest)..['signature'] = signature;

      final isValid = SecurityHelper.verifyManifest(manifestWithSig, signature, secret);
      expect(isValid, isTrue);
    });

    test('verifyManifest fails on modified manifest data', () {
      final manifest = {
        'package_id': 'test-package-123',
        'db_version': '4',
        'schema_version': '4',
        'export_timestamp': '2026-07-05T12:00:00Z',
      };
      final secret = 'test-owner-secret-key-1234567890';
      
      final signature = SecurityHelper.signManifest(manifest, secret);
      final tamperedManifest = Map<String, dynamic>.from(manifest)..['db_version'] = '5';

      final isValid = SecurityHelper.verifyManifest(tamperedManifest, signature, secret);
      expect(isValid, isFalse);
    });

    test('verifyManifest fails on incorrect secret key', () {
      final manifest = {
        'package_id': 'test-package-123',
        'db_version': '4',
        'schema_version': '4',
      };
      final secret = 'test-owner-secret-key-1234567890';
      final wrongSecret = 'wrong-secret-key';
      
      final signature = SecurityHelper.signManifest(manifest, secret);
      final isValid = SecurityHelper.verifyManifest(manifest, signature, wrongSecret);
      expect(isValid, isFalse);
    });
  });
}
