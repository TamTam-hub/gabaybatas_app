// ignore_for_file: deprecated_member_use

class InputValidators {
  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? gmail(String? value) {
    final error = email(value);
    if (error != null) return error;
    if (!value!.trim().toLowerCase().endsWith('@gmail.com')) {
      return 'Use a Gmail address ending in @gmail.com';
    }
    return null;
  }

  static String? phone(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Contact number is required';
    final normalized = input.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(normalized)) {
      return 'Use 09XXXXXXXXX or +639XXXXXXXXX';
    }
    return null;
  }

  static String? age(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Age is required';
    final parsed = int.tryParse(input);
    if (parsed == null || parsed < 12 || parsed > 120) {
      return 'Age must be between 12 and 120';
    }
    return null;
  }

  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Password is required';
    if (input.length < 8) return 'At least 8 characters';
    return null;
  }
}
