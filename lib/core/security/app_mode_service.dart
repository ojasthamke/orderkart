import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';

enum AppMode { owner, worker }

class AppModeService {
  static const String ownerActivationCode = '860549';
  static const String keyAppMode = 'app_mode';
  static const String keyOwnerPinHash = 'owner_pin_hash';
  static const String keyOwnerPinSalt = 'owner_pin_salt';
  static const String keyIsInitialized = 'app_initialized';

  /// Hash a PIN with a salt
  static String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin:$salt');
    return sha256.convert(bytes).toString();
  }

  /// Check if first-launch initialization is complete
  static Future<bool> isAppInitialized() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [keyIsInitialized]);
    return res.isNotEmpty && res.first['value'] == 'true';
  }

  /// Set app initialization status
  static Future<void> setAppInitialized(bool initialized) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('settings', {
      'key': keyIsInitialized,
      'value': initialized ? 'true' : 'false',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get current App Mode
  static Future<AppMode> getAppMode() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [keyAppMode]);
    if (res.isEmpty) return AppMode.owner;
    final val = res.first['value'] as String?;
    return val == 'worker' ? AppMode.worker : AppMode.owner;
  }

  /// Set App Mode
  static Future<void> setAppMode(AppMode mode) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('settings', {
      'key': keyAppMode,
      'value': mode == AppMode.worker ? 'worker' : 'owner',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Check if Owner PIN is set up
  static Future<bool> isOwnerPinSet() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [keyOwnerPinHash]);
    return res.isNotEmpty && (res.first['value'] as String? ?? '').isNotEmpty;
  }

  /// Validate Activation Code ('860549').
  /// Returns false once Owner PIN setup is completed.
  static Future<bool> validateActivationCode(String input) async {
    final pinSet = await isOwnerPinSet();
    if (pinSet) return false; // Default activation code disabled after setup
    return input.trim() == ownerActivationCode;
  }

  /// Save new Owner 6-digit PIN
  static Future<void> setOwnerPin(String pin) async {
    final db = await DatabaseHelper.instance.database;
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = _hashPin(pin.trim(), salt);

    await db.insert('settings', {'key': keyOwnerPinHash, 'value': hash},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('settings', {'key': keyOwnerPinSalt, 'value': salt},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Validate entered Owner PIN against stored hash
  static Future<bool> verifyOwnerPin(String pin) async {
    final db = await DatabaseHelper.instance.database;
    final hashRes = await db.query('settings', where: 'key = ?', whereArgs: [keyOwnerPinHash]);
    final saltRes = await db.query('settings', where: 'key = ?', whereArgs: [keyOwnerPinSalt]);

    if (hashRes.isEmpty || saltRes.isEmpty) return false;
    final storedHash = hashRes.first['value'] as String? ?? '';
    final storedSalt = saltRes.first['value'] as String? ?? '';

    if (storedHash.isEmpty || storedSalt.isEmpty) return false;
    final inputHash = _hashPin(pin.trim(), storedSalt);
    return inputHash == storedHash;
  }
}

final appModeProvider = FutureProvider<AppMode>((ref) async {
  return await AppModeService.getAppMode();
});
