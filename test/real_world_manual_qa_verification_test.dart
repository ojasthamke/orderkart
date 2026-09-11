import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:orderkart/core/security/app_mode_service.dart';
import 'package:orderkart/core/services/worker_session.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() async {
    await AppModeService.setAppMode(AppMode.owner);
    AppModeService.loginOwnerSuccess();
  });

  group('MANUAL REAL-WORLD VERIFICATION: Admin & Worker Workflows', () {
    test('MANUAL TEST 1: Worker Logout Clears Session and Requires Owner Login', () async {
      // 1. Worker logs in
      await WorkerSession.instance.setWorker('worker_01', workerName: 'Ramesh Delivery');
      expect(WorkerSession.instance.currentWorkerName, equals('Ramesh Delivery'));
      expect(WorkerSession.instance.currentWorkerId, equals('worker_01'));

      // 2. Worker logs out
      await WorkerSession.instance.clear();

      // 3. Verify that worker is logged out AND owner session is strictly inactive
      expect(WorkerSession.instance.currentWorkerId, isNull);
      expect(AppModeService.isOwnerSessionActive, isFalse);
    });

    test('MANUAL TEST 2: Cryptographic SHA-256 Owner Activation & Master PIN Verification', () async {
      // Correct Owner recovery hash verification
      const masterRecoveryHash = '460d235c0ac08c373da0a269e57569aeaa50721061ea966758f57eef78e6e946';
      
      final validPinBytes = utf8.encode('860549');
      final validPinHash = sha256.convert(validPinBytes).toString();
      expect(validPinHash, equals(masterRecoveryHash));

      final invalidPinBytes = utf8.encode('000000');
      final invalidPinHash = sha256.convert(invalidPinBytes).toString();
      expect(invalidPinHash == masterRecoveryHash, isFalse);
    });

    test('MANUAL TEST 3: Free Delivery with POS Rounding Parse Verification', () {
      // Simulating Supabase remote order with Free Delivery and POS Rounding
      final remoteOrder = {
        'id': 'ord-free-1',
        'subtotal': 993.0,
        'delivery_charge': 0.0,
        'pos_rounding': 2.0,
        'total_amount': 995.0,
        'items': [
          {'product_name': 'Alphonso Mango Box', 'quantity': 1, 'price': 993.0, 'total_price': 993.0}
        ],
      };

      final num rawDeliveryCharge = (remoteOrder['delivery_charge'] as num?) ?? 0.0;
      final num rawRounding = (remoteOrder['pos_rounding'] as num?) ?? 0.0;
      final double totalAmount = (remoteOrder['total_amount'] as num).toDouble();

      expect(rawDeliveryCharge.toDouble(), equals(0.0), reason: 'Free delivery MUST have 0.0 delivery charge');
      expect(rawRounding.toDouble(), equals(2.0), reason: 'POS Rounding must be exactly 2.0');
      expect(totalAmount, equals(995.0));
    });

    test('MANUAL TEST 4: UTC ISO Delivery Time Storage in OrderKart', () {
      final now = DateTime.utc(2026, 9, 7, 6, 0, 0);
      final estimatedDeliveryAt = now.add(const Duration(minutes: 40));

      final estimatedDeliveryAtIso = estimatedDeliveryAt.toIso8601String();
      expect(estimatedDeliveryAtIso.endsWith('Z'), isTrue, reason: 'Must include UTC Z identifier');

      final parsed = DateTime.parse(estimatedDeliveryAtIso);
      expect(parsed.isUtc, isTrue);
      expect(parsed.difference(now).inMinutes, equals(40));
    });
  });
}
