import 'dart:convert';

class ApiKeyManager {
  // تم تقسيم المفتاح وتشفيره بـ Base64
  static const _p1 = 'QVEuQWI4Uk42TC1RbnhVeENI';
  static const _p2 = 'MnNoX2xtbm93RF9KMG1HNXhC';
  static const _p3 = 'YnJrODJwVFBIYmxMLVNidEE=';

  static String get apiKey {
    try {
      final combined = _p1 + _p2 + _p3;
      return utf8.decode(base64Decode(combined));
    } catch (_) {
      return '';
    }
  }
}
