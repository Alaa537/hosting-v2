import 'dart:convert';

class GroqKeyManager {
  static const _p1 = 'Z3NrX2tGaVR3T0VCNnlLQnhGZ';
  static const _p2 = 'mVxUDc4V0dkeWIzRllsTmlvVU';
  static const _p3 = '4wbVZkZ1VUaXRGdVR2anpYQzY=';

  static String get apiKey {
    try {
      return utf8.decode(base64Decode(_p1 + _p2 + _p3));
    } catch (_) {
      return '';
    }
  }
}
