/// Centralized, industry-standard validators for all forms.
class Validators {
  /// Validates a name field (person name).
  static String? name(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    if (trimmed.length > 100) {
      return '$fieldName cannot exceed 100 characters';
    }
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return '$fieldName cannot be only numbers';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return '$fieldName must contain at least one letter';
    }
    return null;
  }

  /// Validates a roll/registration number.
  static String? rollNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Roll Number is required';
    }
    if (value.trim().length > 20) {
      return 'Roll Number is too long';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Roll Number must contain at least one digit';
    }
    return null;
  }

  /// Validates a required dropdown selection.
  static String? requiredField<T>(T? value, String fieldName) {
    if (value == null) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates a time string.
  static String? time(String? value, {String fieldName = 'Time'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates a phone number.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone Number is required';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^[0-9]{10}$').hasMatch(trimmed)) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }
}
