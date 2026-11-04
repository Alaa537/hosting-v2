import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/bootstrap.dart';
import '../services/api_client.dart';
import '../services/storage.dart';
import '../utils/device_info.dart';

enum AuthState { loading, loggedOut, loggedIn, blocked }

class AuthProvider extends ChangeNotifier {
  AuthState state = AuthState.loading;
  ApiClient? api;
  User? user;
  String baseUrl = '';
  String deviceId = '';
  int appVersion = 1;
  Bootstrap? bootstrap_;
  String? blockedReason;
  String? deviceWarning;

  // =========================================================
  //  BOOTSTRAP
  // =========================================================
  Future<void> bootstrap() async {
    baseUrl = await Store.readBase();
    deviceId = await DeviceInfo.deviceId();
    appVersion = await Store.readAppVersionCode();

    final token = await Store.readToken();
    final refresh = await Store.readRefresh();

    api = ApiClient(baseUrl, onTokenUpdate: (access, rt) async {
      await Store.saveTokens(access, rt);
    })
      ..deviceId = deviceId
      ..appVersion = appVersion;

    if (token != null || refresh != null) {
      api!.setTokens(access: token, refresh: refresh);
    }

    if (refresh != null) {
      try {
        user = await api!.me();
        state = AuthState.loggedIn;
        notifyListeners();
        _ensureDeviceLockInBackground();
        await _loadBootstrapSafe();
        return;
      } on AuthException {
        await Store.clearAuth();
        api!.setTokens();
      } catch (_) {}
    }

    state = AuthState.loggedOut;
    notifyListeners();
  }

  Future<void> _loadBootstrapSafe() async {
    try {
      bootstrap_ = await api!.bootstrap();
      if (bootstrap_!.killSwitch) {
        blockedReason = bootstrap_!.killReason;
        state = AuthState.blocked;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Bootstrap?> loadBootstrap() async {
    if (api == null) return null;
    try {
      bootstrap_ = await api!.bootstrap();
      return bootstrap_;
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  //  LOGIN
  // =========================================================
  Future<String?> login(String u, String p) async {
    try {
      
      final r = await api!.login(u, p);

      await Store.saveTokens(api!.token, api!.refreshToken);
      await Store.saveUsernameHint(u);
      user = await api!.me();
      state = AuthState.loggedIn;
      deviceWarning = null;
      notifyListeners();

      // client-side lock
      await DeviceInfo.lockDeviceTo(u);

      _ensureDeviceLockInBackground();
      await _loadBootstrapSafe();
      return null;
    } on ConflictException catch (e) {
      final code = e.code;
      if (code.contains('device is linked to another')) {
        return 'هذا الجهاز مسجّل بحساب آخر.\n'
               'تواصل مع الدعم لفك القفل.';
      }
      if (code.contains('account is locked to another device')) {
        return 'هذا الحساب مربوط بجهاز آخر.\n'
               'تواصل مع الدعم.';
      }
      return code.isNotEmpty ? code : 'خطأ تعارض في البيانات';
    } on AuthException catch (e) {
      final msg = _detail(e);
      if (msg.contains('PENDING_APPROVAL')) {
        return 'حسابك بانتظار موافقة الأدمن.';
      }
      if (msg.contains('Banned')) {
        return 'تم حظر حسابك.\n$msg';
      }
      if (msg.contains('REJECTED')) {
        return 'تم رفض حسابك.\n$msg';
      }
      if (e.status == 401) {
        return 'اسم المستخدم أو كلمة المرور خطأ';
      }
      if (msg.contains('Maintenance')) {
        return 'السيرفر في وضع الصيانة.';
      }
      return msg.isNotEmpty ? msg : 'فشل تسجيل الدخول (${e.status})';
    } on HostingException catch (e) {
      if (e.status == 0) return 'تعذّر الاتصال بالسيرفر.';
      return _detail(e);
    } catch (e) {
      return 'خطأ: $e';
    }
  }

  // =========================================================
  //  REGISTER
  // =========================================================
  Future<String?> register(String u, String p, String invite) async {
    try {
      
      final r = await api!.register(u, p, invite);

      if (r['status'] == 'pending') {
        final reason = r['reason'] ?? 'admin_required';
        final msg = r['message'] ?? 'طلبك قيد المراجعة من قبل الإدارة.';
        return 'PENDING:$msg|$reason';
      }

      if (r['token'] != null) {
        await Store.saveTokens(api!.token, api!.refreshToken);
        await Store.saveUsernameHint(u);
        user = await api!.me();
        state = AuthState.loggedIn;
        deviceWarning = r['migrated'] == true ? 'تم نقل الجهاز بنجاح' : null;
        notifyListeners();
        await DeviceInfo.lockDeviceTo(u);
        _ensureDeviceLockInBackground();
        await _loadBootstrapSafe();
        return null;
      }
      return 'PENDING:${r['message'] ?? 'قيد المراجعة'}';
    } on ConflictException catch (e) {
      final code = e.code;
      if (code.contains('device is already registered') ||
          code.contains('device is linked')) {
        return 'هذا الجهاز مسجّل بالفعل.\n'
               'لا يمكن إنشاء حساب جديد من نفس الجهاز.';
      }
      if (code.contains('Username already exists')) {
        return 'اسم المستخدم مستخدم مسبقاً.';
      }
      return code.isNotEmpty ? code : 'تعارض في البيانات';
    } on AuthException catch (e) {
      final msg = _detail(e);
      if (msg.contains('Registration closed')) return 'التسجيل مغلق حالياً.';
      if (msg.contains('Invalid invite')) return 'كود الدعوة غير صحيح.';
      return msg.isNotEmpty ? msg : 'فشل التسجيل (${e.status})';
    } on HostingException catch (e) {
      if (e.status == 0) return 'تعذّر الاتصال بالسيرفر.';
      return _detail(e);
    } catch (e) {
      return 'خطأ: $e';
    }
  }

  String _detail(HostingException e) {
    if (e.detail is Map && e.detail['detail'] != null) {
      return e.detail['detail'].toString();
    }
    return e.detail?.toString() ?? '';
  }

  // =========================================================
  //  DEVICE CHECK (background)
  // =========================================================
  Future<void> _ensureDeviceLockInBackground() async {
    try {
      final check = await api!.deviceCheck(deviceId);
      // v5 response: { registered, bound_to_me, bound_at, last_seen }
      final registered = check['registered'] == true;
      final boundToMe = check['bound_to_me'] == true;

      if (registered && !boundToMe) {
        deviceWarning = 'الجهاز مربوط بحساب آخر.';
        notifyListeners();
      } else if (!registered) {
        try { await api!.deviceLock(); } catch (_) {}
      }
    } catch (_) {}
  }

  void clearDeviceWarning() {
    deviceWarning = null;
    notifyListeners();
  }

  // =========================================================
  //  LOGOUT
  // =========================================================
  Future<void> logout() async {
    try { await api!.logout(); } catch (_) {}
    await Store.saveTokens(null, null);
    user = null;
    state = AuthState.loggedOut;
    deviceWarning = null;
    notifyListeners();
  }

  Future<void> logoutAll() async {
    try { await api!.logoutAll(); } catch (_) {}
    await Store.saveTokens(null, null);
    user = null;
    state = AuthState.loggedOut;
    deviceWarning = null;
    notifyListeners();
  }

  Future<void> setBase(String b) async {
    baseUrl = b;
    api?.dispose();
    api = ApiClient(b, onTokenUpdate: (access, rt) async {
      await Store.saveTokens(access, rt);
    })
      ..deviceId = deviceId
      ..appVersion = appVersion;
    await Store.saveBase(b);
    await Store.clearAuth();
    user = null;
    state = AuthState.loggedOut;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    try { user = await api!.me(); notifyListeners(); } catch (_) {}
  }

  Future<void> recheckKillSwitch() async => _loadBootstrapSafe();
}
