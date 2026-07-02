/// Validators — Form field validation rules

class AppValidators {
  AppValidators._();

  static String? required(String? value, {String field = 'Field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final clean = value.replaceAll(RegExp(r'[\s\-()]+'), '');
    if (!RegExp(r'^[+]?[0-9]{7,15}$').hasMatch(clean)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? phoneRequired(String? value) {
    final req = required(value, field: 'Phone number');
    if (req != null) return req;
    return phone(value);
  }

  static String? positiveNumber(String? value, {String field = 'Amount'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final n = double.tryParse(value);
    if (n == null) return 'Enter a valid number';
    if (n < 0) return '$field cannot be negative';
    return null;
  }

  static String? positiveInt(String? value, {String field = 'Value'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    final n = int.tryParse(value);
    if (n == null || n < 0) return 'Enter a valid whole number';
    return null;
  }

  static String? maxLength(String? value, int max, {String field = 'Field'}) {
    if (value != null && value.length > max) {
      return '$field cannot exceed $max characters';
    }
    return null;
  }

  static String? nameField(String? value, {String field = 'Name'}) {
    final req = required(value, field: field);
    if (req != null) return req;
    if (value!.trim().length < 2) return '$field must be at least 2 characters';
    return maxLength(value, 100, field: field);
  }
}
