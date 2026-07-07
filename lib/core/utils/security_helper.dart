// lib/core/utils/security_helper.dart

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../database/database_helper.dart';

class SecurityHelper {
  SecurityHelper._();

  /// Generates a cryptographically secure 256-bit (32-byte) secret encoded as base64url.
  static String generateOwnerSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Retrieves the owner secret key from the settings table.
  /// Generates and saves one if it does not exist yet.
  static Future<String> getOrInitializeOwnerSecret() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> res = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [AppConstants.keyOwnerSecret],
    );

    if (res.isNotEmpty) {
      final secret = res.first['value']?.toString() ?? '';
      if (secret.isNotEmpty) return secret;
    }

    // Generate new secret
    final newSecret = generateOwnerSecret();
    await db.insert(
      'settings',
      {
        'key': AppConstants.keyOwnerSecret,
        'value': newSecret,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return newSecret;
  }

  /// Signs a package manifest by calculating the HMAC-SHA256 signature of its JSON representation
  /// (excluding the signature field itself).
  static String signManifest(Map<String, dynamic> manifestMap, String secretKey) {
    // Exclude 'signature' field if it exists
    final cleanMap = Map<String, dynamic>.from(manifestMap)..remove('signature');
    
    // Sort keys to ensure stable serialization order
    final sortedKeys = cleanMap.keys.toList()..sort();
    final sortedMap = {for (var k in sortedKeys) k: cleanMap[k]};
    
    // Convert to canonical JSON string
    final canonicalJson = json.encode(sortedMap);
    
    // Compute HMAC-SHA256
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(canonicalJson));
    return digest.toString();
  }

  /// Verifies if a manifest's signature matches the re-computed HMAC-SHA256 signature
  /// using the provided secret key.
  static bool verifyManifest(Map<String, dynamic> manifestMap, String signature, String secretKey) {
    if (signature.isEmpty || secretKey.isEmpty) return false;
    final expectedSignature = signManifest(manifestMap, secretKey);
    // Constant-time comparison to prevent timing attacks
    if (expectedSignature.length != signature.length) return false;
    int result = 0;
    for (int i = 0; i < expectedSignature.length; i++) {
      result |= expectedSignature.codeUnitAt(i) ^ signature.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Hashes a worker's numerical PIN using SHA-256 (with a constant salt for offline validation).
  static String hashPin(String pin) {
    if (pin.isEmpty) return '';
    final saltedPin = 'orderkart_salt_$pin';
    return sha256.convert(utf8.encode(saltedPin)).toString();
  }

  /// Encrypts bytes using AES-256 (CBC mode, PKCS7 padding) with a key derived from the secret.
  /// Prepends the 16-byte random IV to the returned encrypted payload.
  static List<int> encryptBytes(List<int> plainBytes, String secret) {
    final keyBytes = sha256.convert(utf8.encode(secret)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    
    final result = <int>[];
    result.addAll(iv.bytes);
    result.addAll(encrypted.bytes);
    return result;
  }

  /// Decrypts bytes that were encrypted using encryptBytes.
  /// Assumes the first 16 bytes are the IV.
  static List<int> decryptBytes(List<int> cipherBytes, String secret) {
    if (cipherBytes.length < 16) {
      throw Exception('Invalid cipher bytes: too short');
    }
    final keyBytes = sha256.convert(utf8.encode(secret)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    
    final ivBytes = cipherBytes.sublist(0, 16);
    final encryptedDataBytes = cipherBytes.sublist(16);
    
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    
    return encrypter.decryptBytes(enc.Encrypted(Uint8List.fromList(encryptedDataBytes)), iv: iv);
  }

  /// Obfuscates a secret key to prevent plaintext storage in JSON/manifest files.
  static String obfuscateSecret(String secret) {
    if (secret.isEmpty) return '';
    try {
      final keyBytes = sha256.convert(utf8.encode('orderkart_obfuscator_salt_12345')).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV(Uint8List(16)); // Fixed IV for stable obfuscation
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.encrypt(secret, iv: iv).base64;
    } catch (_) {
      return '';
    }
  }

  /// Deobfuscates a secret key from manifest files.
  static String deobfuscateSecret(String obfuscated) {
    if (obfuscated.isEmpty) return '';
    try {
      final keyBytes = sha256.convert(utf8.encode('orderkart_obfuscator_salt_12345')).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV(Uint8List(16)); // Fixed IV for stable obfuscation
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(obfuscated, iv: iv);
    } catch (_) {
      return '';
    }
  }
}
