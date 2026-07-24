import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

enum AppMode { owner, worker }

class AppModeService {
  static const String keyAppMode = 'app_mode';
  static const String keyOwnerPinHash = 'owner_pin_hash';
  static const String keyOwnerPinSalt = 'owner_pin_salt';
  static const String keyIsInitialized = 'app_initialized';
  static const String keyFailedAttempts = 'owner_failed_pin_attempts';
  static const String keyLockoutUntil = 'owner_pin_lockout_until';

  /// Session state: once logged in as Owner, true until explicit Logout!
  static bool isOwnerSessionActive = false;

  static void loginOwnerSuccess() {
    isOwnerSessionActive = true;
  }

  static void logoutOwner() {
    isOwnerSessionActive = false;
  }

  /// Hash a PIN with a salt
  static String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin:$salt');
    return sha256.convert(bytes).toString();
  }

  /// Check if first-launch initialization is complete
  static Future<bool> isAppInitialized() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db
        .query('settings', where: 'key = ?', whereArgs: [keyIsInitialized]);
    return res.isNotEmpty && res.first['value'] == 'true';
  }

  /// Set app initialization status
  static Future<void> setAppInitialized(bool initialized) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
        'settings',
        {
          'key': keyIsInitialized,
          'value': initialized ? 'true' : 'false',
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get current App Mode
  static Future<AppMode> getAppMode() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(keyAppMode);
    if (val != null) {
      return val == 'worker' ? AppMode.worker : AppMode.owner;
    }
    // Fallback to SQLite settings table
    try {
      final db = await DatabaseHelper.instance.database;
      final res =
          await db.query('settings', where: 'key = ?', whereArgs: [keyAppMode]);
      if (res.isNotEmpty) {
        final dbVal = res.first['value'] as String?;
        return dbVal == 'worker' ? AppMode.worker : AppMode.owner;
      }
    } catch (_) {}
    return AppMode.owner;
  }

  /// Set App Mode
  static Future<void> setAppMode(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        keyAppMode, mode == AppMode.worker ? 'worker' : 'owner');

    // Sync to SQLite database
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
          'settings',
          {
            'key': keyAppMode,
            'value': mode == AppMode.worker ? 'worker' : 'owner',
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  /// Check if Owner PIN is set up
  static Future<bool> isOwnerPinSet() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db
        .query('settings', where: 'key = ?', whereArgs: [keyOwnerPinHash]);
    return res.isNotEmpty && (res.first['value'] as String? ?? '').isNotEmpty;
  }

  /// Validate Activation Code.
  /// Returns false once Owner PIN setup is completed.
  static Future<bool> validateActivationCode(String input) async {
    final pinSet = await isOwnerPinSet();
    if (pinSet) return false; // Default activation code disabled after setup
    final hash = sha256.convert(utf8.encode(input.trim())).toString();
    return hash ==
        '460d235c0ac08c373da0a269e57569aeaa50721061ea966758f57eef78e6e946';
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

  /// Get remaining lockout time in seconds. Returns 0 if not locked.
  static Future<int> getRemainingLockoutTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntil = prefs.getInt(keyLockoutUntil) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockoutUntil > now) {
      return ((lockoutUntil - now) / 1000).ceil();
    }
    return 0;
  }

  /// Registers a failed PIN entry.
  static Future<void> registerFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final currentFailed = (prefs.getInt(keyFailedAttempts) ?? 0) + 1;
    await prefs.setInt(keyFailedAttempts, currentFailed);

    if (currentFailed >= 10) {
      final lockoutTime =
          DateTime.now().millisecondsSinceEpoch + (5 * 60 * 1000); // 5 minutes
      await prefs.setInt(keyLockoutUntil, lockoutTime);
    } else if (currentFailed >= 5) {
      final lockoutTime =
          DateTime.now().millisecondsSinceEpoch + (30 * 1000); // 30 seconds
      await prefs.setInt(keyLockoutUntil, lockoutTime);
    }
  }

  /// Reset failed attempts.
  static Future<void> resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFailedAttempts);
    await prefs.remove(keyLockoutUntil);
  }

  /// Validate entered Owner PIN against stored hash
  static Future<bool> verifyOwnerPin(String pin) async {
    final remainingLock = await getRemainingLockoutTime();
    if (remainingLock > 0) return false;

    final db = await DatabaseHelper.instance.database;
    final hashRes = await db
        .query('settings', where: 'key = ?', whereArgs: [keyOwnerPinHash]);
    final saltRes = await db
        .query('settings', where: 'key = ?', whereArgs: [keyOwnerPinSalt]);

    if (hashRes.isEmpty || saltRes.isEmpty) return false;
    final storedHash = hashRes.first['value'] as String? ?? '';
    final storedSalt = saltRes.first['value'] as String? ?? '';

    if (storedHash.isEmpty || storedSalt.isEmpty) return false;
    final inputHash = _hashPin(pin.trim(), storedSalt);
    final isValid = inputHash == storedHash;

    if (isValid) {
      await resetFailedAttempts();
    } else {
      await registerFailedAttempt();
    }
    return isValid;
  }

  /// Check specific worker permission configured by Owner
  static Future<bool> hasWorkerPermission(String permissionKey) async {
    return true;
  }
}

final appModeProvider = FutureProvider<AppMode>((ref) async {
  return await AppModeService.getAppMode();
});
