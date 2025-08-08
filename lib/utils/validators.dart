// lib/utils/validators.dart
class Validators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    const pattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
    final regExp = RegExp(pattern);

    if (!regExp.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }

    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    if (value.length < 2) {
      return 'Name must be at least 2 characters long';
    }

    return null;
  }

  // Phone number validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Allow "+" and digits only
    const pattern = r'^\+?[0-9]{10,15}$';
    final regExp = RegExp(pattern);

    if (!regExp.hasMatch(value)) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  // ID number validation (South African)
  static String? validateIdNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'ID number is required';
    }

    if (value.length != 13) {
      return 'ID number must be 13 digits';
    }

    // Check if all characters are digits
    const pattern = r'^[0-9]{13}$';
    final regExp = RegExp(pattern);

    if (!regExp.hasMatch(value)) {
      return 'ID number must contain only digits';
    }

    return null;
  }

  // Vehicle license plate validation
  static String? validateLicensePlate(String? value) {
    // Very relaxed: only require something after trimming
    if (value == null || value.trim().isEmpty) {
      return 'License plate is required';
    }
    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }
}
