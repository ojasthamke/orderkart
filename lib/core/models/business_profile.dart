// lib/core/models/business_profile.dart

class BusinessProfile {
  final String id;
  final String businessName;
  final String ownerName;
  final String phone;
  final String whatsapp;
  final String email;
  final String address;
  final String gstNumber;
  final String upiId;
  final String logoPath;
  final String qrPath;
  final String invoiceFooter;
  final String bankDetails;
  final String supportNumber;
  final String termsConditions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusinessProfile({
    required this.id,
    this.businessName = 'OrderKart',
    this.ownerName = '',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.address = '',
    this.gstNumber = '',
    this.upiId = '',
    this.logoPath = '',
    this.qrPath = '',
    this.invoiceFooter = '',
    this.bankDetails = '',
    this.supportNumber = '',
    this.termsConditions = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessProfile.fromMap(Map<String, dynamic> map) {
    return BusinessProfile(
      id: map['id'] as String,
      businessName: map['business_name'] as String? ?? 'OrderKart',
      ownerName: map['owner_name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      whatsapp: map['whatsapp'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      gstNumber: map['gst_number'] as String? ?? '',
      upiId: map['upi_id'] as String? ?? '',
      logoPath: map['logo_path'] as String? ?? '',
      qrPath: map['qr_path'] as String? ?? '',
      invoiceFooter: map['invoice_footer'] as String? ?? '',
      bankDetails: map['bank_details'] as String? ?? '',
      supportNumber: map['support_number'] as String? ?? '',
      termsConditions: map['terms_conditions'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'business_name': businessName,
        'owner_name': ownerName,
        'phone': phone,
        'whatsapp': whatsapp,
        'email': email,
        'address': address,
        'gst_number': gstNumber,
        'upi_id': upiId,
        'logo_path': logoPath,
        'qr_path': qrPath,
        'invoice_footer': invoiceFooter,
        'bank_details': bankDetails,
        'support_number': supportNumber,
        'terms_conditions': termsConditions,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  BusinessProfile copyWith({
    String? id,
    String? businessName,
    String? ownerName,
    String? phone,
    String? whatsapp,
    String? email,
    String? address,
    String? gstNumber,
    String? upiId,
    String? logoPath,
    String? qrPath,
    String? invoiceFooter,
    String? bankDetails,
    String? supportNumber,
    String? termsConditions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessProfile(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      email: email ?? this.email,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      upiId: upiId ?? this.upiId,
      logoPath: logoPath ?? this.logoPath,
      qrPath: qrPath ?? this.qrPath,
      invoiceFooter: invoiceFooter ?? this.invoiceFooter,
      bankDetails: bankDetails ?? this.bankDetails,
      supportNumber: supportNumber ?? this.supportNumber,
      termsConditions: termsConditions ?? this.termsConditions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
