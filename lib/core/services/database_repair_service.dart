import 'dart:io';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';

class RepairResult {
  final int missingPhotosFixed;
  final int orphanOrderItemsCleaned;
  final int orphanStreetsCleaned;
  final String statusSummary;

  const RepairResult({
    required this.missingPhotosFixed,
    required this.orphanOrderItemsCleaned,
    required this.orphanStreetsCleaned,
    required this.statusSummary,
  });
}

class DatabaseRepairService {
  DatabaseRepairService._();

  static Future<RepairResult> runDiagnosticsAndRepair() async {
    final db = await DatabaseHelper.instance.database;
    const uuid = Uuid();

    int fixedPhotos = 0;
    int cleanedOrderItems = 0;
    int cleanedStreets = 0;

    // 1. Scan customer photo paths
    final customers =
        await db.query('customers', columns: ['id', 'photo_path']);
    for (final c in customers) {
      final path = c['photo_path'] as String? ?? '';
      if (path.isNotEmpty) {
        final file = File(path);
        if (!file.existsSync()) {
          final fallback = AppConstants.resolveFile(path);
          if (!fallback.existsSync()) {
            // Reset broken path
            await db.update('customers', {'photo_path': ''},
                where: 'id = ?', whereArgs: [c['id']]);
            fixedPhotos++;
          }
        }
      }
    }

    // 2. Clean orphan order_items
    final orphanItems = await db.rawQuery('''
      SELECT oi.id FROM order_items oi
      LEFT JOIN orders o ON oi.order_id = o.id
      WHERE o.id IS NULL
    ''');
    for (final oi in orphanItems) {
      await db.delete('order_items', where: 'id = ?', whereArgs: [oi['id']]);
      cleanedOrderItems++;
    }

    // 3. Clean orphan streets
    final orphanStreets = await db.rawQuery('''
      SELECT s.id FROM streets s
      LEFT JOIN areas a ON s.area_id = a.id
      WHERE a.id IS NULL
    ''');
    for (final s in orphanStreets) {
      await db.delete('streets', where: 'id = ?', whereArgs: [s['id']]);
      cleanedStreets++;
    }

    final summary =
        'Diagnostic Repair Complete: $fixedPhotos broken photo links reset, $cleanedOrderItems orphan items cleaned, $cleanedStreets orphan streets cleaned.';

    // Log diagnostic run
    await db.insert('repair_logs', {
      'id': uuid.v4(),
      'date': DateTime.now().toIso8601String(),
      'issue_type': 'database_diagnostics',
      'details':
          'Fixed photos: $fixedPhotos, Cleaned items: $cleanedOrderItems, Cleaned streets: $cleanedStreets',
      'action_taken': 'auto_repair',
    });

    return RepairResult(
      missingPhotosFixed: fixedPhotos,
      orphanOrderItemsCleaned: cleanedOrderItems,
      orphanStreetsCleaned: cleanedStreets,
      statusSummary: summary,
    );
  }
}
