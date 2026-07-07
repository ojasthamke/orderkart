/// String Extensions
library;

extension StringExtensions on String {
  String get capitalised {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  String get titleCase {
    return split(' ').map((w) => w.capitalised).join(' ');
  }

  bool get isValidPhone {
    final clean = replaceAll(RegExp(r'[\s\-()]+'), '');
    return RegExp(r'^[+]?[0-9]{7,15}$').hasMatch(clean);
  }

  String get whatsappUrl {
    final clean = replaceAll(RegExp(r'[^0-9+]'), '');
    return 'https://wa.me/$clean';
  }

  String get telUrl => 'tel:$this';

  bool get isNullOrEmpty => trim().isEmpty;
}
