import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum SecurityStatus {
  ok, vpn, mitm, tampered, ssl,
  rooted, frida, emulator, debugger, xposed, error,
}

class SecurityResult {
  final SecurityStatus status;
  final String? message;
  final Map<String, dynamic> debug;

  SecurityResult._(this.status, [this.message, this.debug = const {}]);

  factory SecurityResult.ok() => SecurityResult._(SecurityStatus.ok);
  factory SecurityResult.vpn([String? m]) => SecurityResult._(SecurityStatus.vpn, m ?? 'VPN نشط');
  factory SecurityResult.mitm([String? m]) => SecurityResult._(SecurityStatus.mitm, m ?? 'أداة مراقبة');
  factory SecurityResult.tampered(String m, [Map<String, dynamic>? d]) => SecurityResult._(SecurityStatus.tampered, m, d ?? const {});
  factory SecurityResult.rooted() => SecurityResult._(SecurityStatus.rooted, 'Rooted');
  factory SecurityResult.frida() => SecurityResult._(SecurityStatus.frida, 'Frida');
  factory SecurityResult.debugger() => SecurityResult._(SecurityStatus.debugger, 'Debugger');
  factory SecurityResult.xposed() => SecurityResult._(SecurityStatus.xposed, 'Xposed');
  factory SecurityResult.error(String m, [Map<String, dynamic>? d]) => SecurityResult._(SecurityStatus.error, m, d ?? const {});

  bool get isOk => status == SecurityStatus.ok;
}

class SecurityService {
  static const _channel = MethodChannel('hosting/security');

  // استخدام GitHub API (بدون كاش) كخيار أول
  static const _apiUrl = 'https://api.github.com/repos/Alaa537/hosting-sec-v2/contents/signature.json';
  
  // كخيار احتياطي لو الـ API فشل
  static const _fallbackUrl = 'https://cdn.jsdelivr.net/gh/Alaa537/hosting-sec-v2@main/signature.json';

  static Future<T?> _native<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } catch (_) {
      return null;
    }
  }

  static Future<SecurityResult> verify() async {
    if (await _native<bool>('isDebuggable') == true) return SecurityResult.debugger();
    if (await _native<bool>('isRooted') == true) return SecurityResult.rooted();
    if (await _native<bool>('isFridaRunning') == true) return SecurityResult.frida();
    if (await _native<bool>('hasXposed') == true) return SecurityResult.xposed();
    if (await _native<bool>('isVpnActive') == true) return SecurityResult.vpn();

    final proxy = await _native<String>('getHttpProxy');
    if (proxy != null && proxy.isNotEmpty) return SecurityResult.mitm('Proxy: $proxy');
    
    final procs = (await _native<String>('getRunningProcs') ?? '').toLowerCase();
    for (final n in ['canary', 'charles', 'fiddler', 'mitmproxy', 'burpsuite', 'reqable']) {
      if (procs.contains(n)) return SecurityResult.mitm('Process: $n');
    }

    return await _checkSignature();
  }

  static Future<SecurityResult> _checkSignature() async {
    final localRaw = await _native<String>('getApkSignatureSha256');
    if (localRaw == null || localRaw.isEmpty) {
      return SecurityResult.tampered('no_local: لم يُقرأ SHA من التطبيق', {'step': 'read_local'});
    }
    final local = _norm(localRaw);

    // 1. المحاولة عبر GitHub API (سريع وبدون كاش)
    String? remote = await _fetchShaFromApi();
    
    // 2. لو فشل، نجرب jsDelivr
    if (remote == null) {
      remote = await _fetchShaFromUrl(_fallbackUrl);
    }

    if (remote == null) {
      return SecurityResult.error('تعذّر قراءة signature.json من كل المصادر');
    }

    if (local != remote) {
      return SecurityResult.tampered(
        'mismatch\n'
        'Local:  ${local.substring(0, 16)}…\n'
        'Remote: ${remote.substring(0, 16)}…',
        {'step': 'compare', 'local': local, 'remote': remote},
      );
    }

    return SecurityResult.ok();
  }

  static Future<String?> _fetchShaFromApi() async {
    try {
      final r = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.raw',
          'User-Agent': 'hosting-app/1.0',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (r.statusCode != 200) return null;
      
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final sigs = j['signatures'] as Map<String, dynamic>?;
      final sha = _norm(sigs?['sha256']?.toString() ?? '');
      return sha.isEmpty ? null : sha;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetchShaFromUrl(String url) async {
    final finalUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    try {
      final r = await http.get(
        Uri.parse(finalUrl),
        headers: {
          'User-Agent': 'hosting-app/1.0',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (r.statusCode != 200) return null;
      
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final sigs = j['signatures'] as Map<String, dynamic>?;
      final sha = _norm(sigs?['sha256']?.toString() ?? '');
      return sha.isEmpty ? null : sha;
    } catch (_) {
      return null;
    }
  }

  static String _norm(String s) => s.replaceAll(':', '').replaceAll(' ', '').toLowerCase().trim();
}
