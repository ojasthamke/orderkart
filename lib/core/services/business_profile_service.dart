// lib/core/services/business_profile_service.dart

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/business_profile.dart';

class BusinessProfileService {
  BusinessProfileService._();

  /// Retrieve the current business profile.
  /// If it does not exist, a default profile is created and returned.
  static Future<BusinessProfile> getProfile() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('business_profile', limit: 1);

    if (maps.isEmpty) {
      final now = DateTime.now();
      final defaultProfile = BusinessProfile(
        id: 'default_business_id',
        businessName: 'OrderKart Enterprise',
        ownerName: 'Owner',
        phone: '',
        whatsapp: '',
        email: '',
        address: '',
        gstNumber: '',
        upiId: '',
        logoPath: '',
        qrPath: '',
        invoiceFooter: '',
        bankDetails: '',
        supportNumber: '',
        termsConditions: '',
        createdAt: now,
        updatedAt: now,
      );
      await saveProfile(defaultProfile);
      return defaultProfile;
    }

    return BusinessProfile.fromMap(maps.first);
  }

  /// Save or update the business profile.
  static Future<void> saveProfile(BusinessProfile profile) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'business_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
