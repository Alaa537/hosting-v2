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
  final Map<String, dynamic> debug;  // ← معلومات إضافية للتشخيص

  SecurityResult._(this.status, [this.message, this.debug = const {}]);

  factory SecurityResult.ok() => SecurityResult._(SecurityStatus.ok);
  factory SecurityResult.vpn([String? m]) =>
      SecurityResult._(SecurityStatus.vpn, m ?? 'VPN نشط');
  factory SecurityResult.mitm([String? m]) =>
      SecurityResult._(SecurityStatus.mitm, m ?? 'أداة مراقبة');
  factory SecurityResult.tampered(String m, [Map<String, dynamic>? d]) =>
      SecurityResult._(SecurityStatus.tampered, m, d ?? const {});
  factory SecurityResult.rooted() => SecurityResult._(SecurityStatus.rooted, 'Rooted');
  factory SecurityResult.frida() => SecurityResult._(SecurityStatus.frida, 'Frida');
  factory SecurityResult.debugger() => SecurityResult._(SecurityStatus.debugger, 'Debugger');
  factory SecurityResult.xposed() => SecurityResult._(SecurityStatus.xposed, 'Xposed');
  factory SecurityResult.error(String m, [Map<String, dynamic>? d]) =>
      SecurityResult._(SecurityStatus.error, m, d ?? const {});

  bool get isOk => status == SecurityStatus.ok;
}

class SecurityService {
  static const _channel = MethodChannel('hosting/security');

  static const _sources = [
    'https://raw.githubusercontent.com/Alaa537/hosting-sec-v2/main/signature.json',
    'https://cdn.jsdelivr.net/gh/Alaa537/hosting-sec-v2@main/signature.json',
    'https://cdn.statically.io/gh/Alaa537/hosting-sec-v2/main/signature.json',
  ];

  static Future<T?> _native<T>(String method) async {
    try { return await _channel.invokeMethod<T>(method); } catch (_) { return null; }
  }

  static Future<SecurityResult> verify() async {
    // 1) Debugger
    if (await _native<bool>('isDebuggable') == true) return SecurityResult.debugger();
    // 2) Root
    if (await _native<bool>('isRooted') == true) return SecurityResult.rooted();
    // 3) Frida
    if (await _native<bool>('isFridaRunning') == true) return SecurityResult.frida();
    // 4) Xposed
    if (await _native<bool>('hasXposed') == true) return SecurityResult.xposed();
    // 5) VPN
    if (await _native<bool>('isVpnActive') == true) return SecurityResult.vpn();
    // 6) MITM
    final proxy = await _native<String>('getHttpProxy');
    if (proxy != null && proxy.isNotEmpty) {
      return SecurityResult.mitm('Proxy: $proxy');
    }
    final procs = (await _native<String>('getRunningProcs') ?? '').toLowerCase();
    for (final n in ['canary','charles','fiddler','mitmproxy','burpsuite','reqable']) {
      if (procs.contains(n)) return SecurityResult.mitm('Process: $n');
    }
    // 7) Signature
    return await _checkSignature();
  }

  static Future<SecurityResult> _checkSignature() async {
    // Local SHA (native)
    final localRaw = await _native<String>('getApkSignatureSha256');
    if (localRaw == null || localRaw.isEmpty) {
      return SecurityResult.tampered('no_local: لم يُقرأ SHA من التطبيق', {
        'step': 'read_local',
      });
    }
    final local = _norm(localRaw);

    // Fetch remote (Dart HTTP)
    String? remote;
    final errors = <String>[];
    for (final base in _sources) {
      final url = '$base?t=${DateTime.now().millisecondsSinceEpoch}';
      try {
        final r = await http.get(Uri.parse(url),
            headers: {
              'User-Agent': 'hosting-app/1.0',
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            })
            .timeout(const Duration(seconds: 8));
        if (r.statusCode != 200) {
          errors.add('${Uri.parse(base).host}: HTTP ${r.statusCode}');
          continue;
        }
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final sigs = j['signatures'] as Map<String, dynamic>?;
        final v = _norm(sigs?['sha256']?.toString() ?? '');
        if (v.isNotEmpty) { remote = v; break; }
        errors.add('${Uri.parse(base).host}: empty sha256');
      } catch (e) {
        errors.add('${Uri.parse(base).host}: $e');
      }
    }

    if (remote == null) {
      return SecurityResult.tampered(
        'no_remote: تعذّر قراءة SHA من GitHub\n${errors.join("\n")}',
        {'step': 'fetch_remote', 'errors': errors, 'local': local},
      );
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

  static String _norm(String s) =>
      s.replaceAll(':', '').replaceAll(' ', '').toLowerCase().trim();
}
