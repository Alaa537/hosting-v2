import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../models/models.dart';
import '../models/bootstrap.dart';
import '../models/app_models.dart';

class HostingException implements Exception {
  final int status;
  final dynamic detail;
  final String url;
  HostingException(this.status, this.detail, this.url);
  String get message {
    dynamic d = detail;
    if (d is Map && d.containsKey('detail')) d = d['detail'];
    if (d is Map && d.containsKey('error')) d = d['error'];
    if (d is Map && d.containsKey('message')) d = d['message'];
    return d.toString();
  }
  @override
  String toString() => message;
}

class AuthException extends HostingException { AuthException(super.status, super.detail, super.url); }
class TokenExpiredException extends AuthException { TokenExpiredException(super.status, super.detail, super.url); }
class ConflictException extends HostingException {
  ConflictException(super.status, super.detail, super.url);
  String get code => detail is Map ? (detail['code'] ?? detail['detail'] ?? '') : '';
}

typedef TokenCallback = void Function(String? access, String? refresh);

class ApiClient {
  final String baseUrl;
  String? _token;
  String? _refreshToken;
  String? _deviceId;
  String? _appSignature;
  int _appVersion = 1;
  
  // ⚠️ ضع الـ APP_SECRET هنا لما المطور يبعتهولك
  static const String _appSecret = "b7e3f9a2c5d1e8f4a6b9c3d7e2f5a8b1c4d9e6f3a7b2c5d8e1f4a9b6c3d7e2f5"; 

  DateTime? _expiresAt;
  final http.Client _http = http.Client();
  final TokenCallback? onTokenUpdate;
  Future<bool>? _refreshing;

  ApiClient(this.baseUrl, {this.onTokenUpdate});

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get deviceId => _deviceId;
  set deviceId(String? id) => _deviceId = id;
  set appVersion(int v) => _appVersion = v;

  void setTokens({String? access, String? refresh, int? expiresInSeconds}) {
    _token = access;
    _refreshToken = refresh;
    if (expiresInSeconds != null && expiresInSeconds > 0) {
      final safeTtl = expiresInSeconds > 90 ? expiresInSeconds - 60 : expiresInSeconds;
      _expiresAt = DateTime.now().add(Duration(seconds: safeTtl));
    } else {
      _expiresAt = null;
    }
    onTokenUpdate?.call(_token, _refreshToken);
  }

  bool get _needsRefresh {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    if (_token == null || _token!.isEmpty) return true;
    if (_expiresAt != null && DateTime.now().isAfter(_expiresAt!)) return true;
    return false;
  }

  Future<void> _loadSignature() async {
    if (_appSignature != null) return;
    try {
      const channel = MethodChannel('hosting/security');
      _appSignature = await channel.invokeMethod<String>('getApkSignatureSha256');
    } catch (_) {
      _appSignature = '';
    }
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'X-App-Version': '$_appVersion',
        if (_appSignature != null) 'X-App-Signature': _appSignature!,
        if (_deviceId != null) 'X-Device-Id': _deviceId!,
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _u(String path, [Map<String, dynamic>? q]) {
    final uri = Uri.parse('$baseUrl$path');
    if (q == null || q.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...q.map((k, v) => MapEntry(k, '$v')),
    });
  }

  dynamic _sortKeysRecursive(dynamic value) {
    if (value is Map) {
      final sorted = <String, dynamic>{};
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      for (final k in keys) { sorted[k] = _sortKeysRecursive(value[k]); }
      return sorted;
    } else if (value is List) {
      return value.map(_sortKeysRecursive).toList();
    }
    return value;
  }

  Future<dynamic> _decode(http.Response r) async {
    if (r.statusCode >= 400) {
      dynamic detail;
      try { detail = jsonDecode(r.body); }
      catch (_) { detail = r.body.isNotEmpty ? r.body : r.reasonPhrase; }
      
      final code = detail is Map ? (detail['code'] ?? '') : '';
      if (r.statusCode == 401) throw TokenExpiredException(r.statusCode, detail, r.request?.url.toString() ?? '');
      if (r.statusCode == 403) {
        if (code == 'invalid_signature' || code == 'version_blocked' || code == 'device_blocked') {
          throw HostingException(r.statusCode, detail, r.request?.url.toString() ?? '');
        }
        throw AuthException(r.statusCode, detail, r.request?.url.toString() ?? '');
      }
      if (r.statusCode == 409) throw ConflictException(r.statusCode, detail, r.request?.url.toString() ?? '');
      throw HostingException(r.statusCode, detail, r.request?.url.toString() ?? '');
    }

    if (r.body.isEmpty) return null;
    final parsed = jsonDecode(r.body);

    // HMAC Verification
    if (parsed is Map && parsed.containsKey('sig') && parsed.containsKey('ts') && parsed.containsKey('data')) {
      final data = parsed['data'];
      final sig = parsed['sig'] as String;
      final ts = parsed['ts'];
      
      final canonical = jsonEncode(_sortKeysRecursive(data));
      final msg = utf8.encode(canonical + ts.toString());
      final hmac = Hmac(sha256, utf8.encode(_appSecret));
      final expected = hmac.convert(msg).toString();
      
      if (expected.toLowerCase() != sig.toLowerCase()) {
        throw HostingException(400, {'error': 'Tampered response (HMAC mismatch)'}, r.request?.url.toString() ?? '');
      }
      return data;
    }
    
    return parsed;
  }

  Future<bool> refresh() async {
    if (_refreshing != null) return _refreshing!;
    final completer = Completer<bool>();
    _refreshing = completer.future;
    try {
      final rt = _refreshToken;
      if (rt == null || rt.isEmpty) { completer.complete(false); return false; }
      final r = await _http.post(_u('/auth/refresh'), headers: {..._headers, 'Content-Type': 'application/json'}, body: jsonEncode({'refresh_token': rt}));
      if (r.statusCode >= 400) { setTokens(); completer.complete(false); return false; }
      final data = await _decode(r) as Map<String, dynamic>;
      setTokens(access: data['token'], refresh: data['refresh_token'], expiresInSeconds: data['expires_in']);
      completer.complete(true); return true;
    } catch (_) { completer.complete(false); return false; } finally { _refreshing = null; }
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, dynamic>? q, bool retry = true}) async {
    await _loadSignature();
    if (retry && _needsRefresh) await refresh();
    try {
      http.Response r;
      switch (method) {
        case 'GET': r = await _http.get(_u(path, q), headers: _headers).timeout(const Duration(seconds: 15)); break;
        case 'POST': r = await _http.post(_u(path, q), headers: {..._headers, 'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 15)); break;
        case 'PUT': r = await _http.put(_u(path, q), headers: {..._headers, 'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 15)); break;
        case 'DELETE': r = await _http.delete(_u(path, q), headers: body == null ? _headers : {..._headers, 'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 15)); break;
        default: throw ArgumentError('method');
      }
      return await _decode(r);
    } on TokenExpiredException {
      if (retry && await refresh()) return _send(method, path, body: body, q: q, retry: false);
      rethrow;
    }
  }

  Future<dynamic> _get(String p, {Map<String, dynamic>? q}) => _send('GET', p, q: q);
  Future<dynamic> _post(String p, {Object? body, Map<String, dynamic>? q}) => _send('POST', p, body: body, q: q);
  Future<dynamic> _put(String p, {Object? body}) => _send('PUT', p, body: body);
  Future<dynamic> _del(String p, {Map<String, dynamic>? q, Object? body}) => _send('DELETE', p, q: q, body: body);

  // ====== CHECK VERSION ======
  Future<Map<String, dynamic>> checkVersion() async {
    await _loadSignature();
    final q = {
      'version_code': '$_appVersion',
      'signature': _appSignature ?? '',
      'device_id': _deviceId ?? '',
    };
    final r = await _http.get(
      _u('/client/check-version', q),
      headers: {
        'Accept': 'application/json',
        'X-App-Version': '$_appVersion',
        if (_appSignature != null) 'X-App-Signature': _appSignature!,
        if (_deviceId != null) 'X-Device-Id': _deviceId!,
      },
    ).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw HostingException(r.statusCode, 'Version check failed', r.request?.url.toString() ?? '');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ====== AUTH ======
  Future<Map<String, dynamic>> login(String u, String p) async {
    final body = <String, dynamic>{'username': u, 'password': p, 'device_id': _deviceId, 'platform': Platform.operatingSystem, 'app_version': '$_appVersion'};
    final r = await _send('POST', '/auth/login', body: body, retry: false);
    final m = Map<String, dynamic>.from(r);
    if (m['token'] != null) setTokens(access: m['token'], refresh: m['refresh_token'], expiresInSeconds: m['expires_in']);
    return m;
  }

  Future<Map<String, dynamic>> register(String u, String p, String invite) async {
    final body = <String, dynamic>{'username': u, 'password': p, 'invite': invite, 'device_id': _deviceId, 'platform': Platform.operatingSystem, 'app_version': '$_appVersion'};
    final r = await _send('POST', '/auth/register', body: body, retry: false);
    final m = Map<String, dynamic>.from(r);
    if (m['token'] != null) setTokens(access: m['token'], refresh: m['refresh_token'], expiresInSeconds: m['expires_in']);
    return m;
  }
  
  // ... (باقي الدوال كما هي: logout, me, appStatus, listFiles, إلخ) ...

  Future<void> logout() async { try { await _post('/auth/logout', body: {'refresh_token': _refreshToken}); } finally { setTokens(); } }
  Future<void> logoutAll() async { try { await _post('/auth/logout-all'); } finally { setTokens(); } }
  Future<void> changePassword(String o, String n) => _post('/me/password', body: {'old_password': o, 'new_password': n});
  Future<User> me() async => User.fromJson(Map<String, dynamic>.from(await _get('/me')));
  Future<Map<String, dynamic>> sessions() async => Map<String, dynamic>.from(await _get('/auth/sessions'));
  Future<void> revokeSession(int id) => _post('/auth/sessions/revoke', body: {'session_id': id});
  Future<Map<String, dynamic>> deviceLock() async => Map<String, dynamic>.from(await _post('/auth/device-lock', body: {'device_id': _deviceId}));
  Future<Map<String, dynamic>> deviceCheck(String deviceId) async => Map<String, dynamic>.from(await _get('/auth/device-lock', q: {'device_id': deviceId}));
  Future<Map<String, dynamic>> myDevices() async => Map<String, dynamic>.from(await _get('/me/devices'));
  Future<Bootstrap> bootstrap() async => Bootstrap.fromJson(Map<String, dynamic>.from(await _get('/client/bootstrap', q: {'device_id': _deviceId ?? '', 'app_version': '$_appVersion'})));
  Future<void> dismissModal(int id) => _post('/client/modal-dismiss', body: {'modal_id': id});
  Future<Map<String, dynamic>> usage() async => Map<String, dynamic>.from(await _get('/me/usage'));
  Future<Map<String, dynamic>> activity({int limit = 50}) async => Map<String, dynamic>.from(await _get('/me/activity', q: {'limit': limit}));
  Future<Map<String, dynamic>> alerts({int limit = 50}) async => Map<String, dynamic>.from(await _get('/me/alerts', q: {'limit': limit}));
  Future<void> alertsRead([List<int>? ids]) => _post('/me/alerts/read', body: {'ids': ids});
  
  Future<AppStatus> appStatus() async => AppStatus.fromJson(Map<String, dynamic>.from(await _get('/app')));
  Future<String> appRead() async { final r = await _get('/app/file'); if (r is Map) return r['content'] as String? ?? ''; return r.toString(); }
  Future<void> appWrite(String content) => _post('/app/file', body: {'content': content});
  Future<void> appStart() => _post('/app/start');
  Future<void> appStop() => _post('/app/stop');
  Future<void> appRestart() => _post('/app/restart');
  Future<void> appKill() => _post('/app/kill');
  Future<void> appCommand(String cmd) => _post('/app/command', body: {'command': cmd});
  Future<Map<String, dynamic>> appUpload(File file, {File? requirements}) async {
    final req = http.MultipartRequest('POST', _u('/app/upload'));
    req.headers.addAll(_headers);
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    if (requirements != null) req.files.add(await http.MultipartFile.fromPath('requirements', requirements.path));
    final streamed = await req.send();
    return Map<String, dynamic>.from(await _decode(await http.Response.fromStream(streamed)) ?? {});
  }

  Future<List<Map<String, dynamic>>> listFiles({String directory = '/'}) async => (await _get('/files', q: {'directory': directory}) as List).cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> readFileRaw(String file) async => Map<String, dynamic>.from(await _get('/files/content', q: {'file': file}));
  Future<void> writeFileRaw(String file, String content) => _post('/files/write', body: {'file': file, 'content': content});
  Future<void> deleteFiles(String root, List<String> items) => _post('/files/batch', body: {'op': 'delete', 'root': root, 'items': items});
  Future<Map<String, dynamic>> searchFiles(String q, {String directory = '/'}) async => Map<String, dynamic>.from(await _get('/files/search', q: {'q': q, 'directory': directory}));
  Future<Map<String, dynamic>> filesBatch(String op, List<String> items, {String root = '/', String? dest}) async => Map<String, dynamic>.from(await _post('/files/batch', body: {'op': op, 'root': root, 'items': items, if (dest != null) 'destination': dest}));
  
  Future<Map<String, dynamic>> backups() async => Map<String, dynamic>.from(await _get('/backups'));
  Future<void> backupCreate(String name) => _post('/backups', body: {'name': name});
  Future<void> backupRestore(String uuid) => _post('/backups/$uuid/restore');
  Future<void> backupDelete(String uuid) => _del('/backups/$uuid');
  Future<Map<String, dynamic>> backupPolicyGet() async => Map<String, dynamic>.from(await _get('/backups/policy'));
  Future<void> backupPolicySet(bool en, int hours, int keep) => _put('/backups/policy', body: {'enabled': en, 'interval_hours': hours, 'keep': keep});
  
  Future<ServerResources> serverResources() async => ServerResources.fromJson(Map<String, dynamic>.from(await _get('/server/resources')));
  Future<void> power(String s) => _post('/server/power', body: {'signal': s});
  Future<void> setAutoRestart(bool e) => _put('/server/auto-restart', body: {'enabled': e});
  
  Future<List<Announcement>> announcements() async => (await _get('/announcements') as List).map((e) => Announcement.fromJson(e)).toList();
  Future<List<NotificationItem>> notifications({int limit = 50}) async => (await _get('/notifications', q: {'limit': limit}) as List).map((e) => NotificationItem.fromJson(e)).toList();
  Future<void> notificationsRead() => _post('/notifications/read');
  Future<void> notificationsClear() => _del('/notifications');

  Future<WebSocket> connectEvents() async {
    final ws = baseUrl.replaceFirst('http', 'ws');
    return WebSocket.connect('$ws/ws/events?token=$_token');
  }

  void dispose() => _http.close();
}
