import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

/// Secure store for auth tokens + preferences for base URL / device ID.
class Store {
  static const _kToken = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kBase  = 'base_url';
  static const _kDevice = 'device_id';
  static const _kUsername = 'username_hint';
  static const _kAppVer = 'app_version';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ------- tokens (secure) -------
  static Future<String?> readToken() => _secure.read(key: _kToken);
  static Future<String?> readRefresh() => _secure.read(key: _kRefresh);

  static Future<void> saveTokens(String? token, String? refresh) async {
    if (token == null) {
      await _secure.delete(key: _kToken);
    } else {
      await _secure.write(key: _kToken, value: token);
    }
    if (refresh == null) {
      await _secure.delete(key: _kRefresh);
    } else {
      await _secure.write(key: _kRefresh, value: refresh);
    }
  }

  // ------- prefs -------
  static Future<String> readBase() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kBase) ?? kApiBaseDefault;
  }

  static Future<void> saveBase(String b) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBase, b);
  }

  static Future<String?> readDeviceId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kDevice);
  }

  static Future<void> saveDeviceId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDevice, id);
  }

  static Future<String?> readUsernameHint() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kUsername);
  }

  static Future<void> saveUsernameHint(String? u) async {
    final p = await SharedPreferences.getInstance();
    if (u == null) {
      await p.remove(_kUsername);
    } else {
      await p.setString(_kUsername, u);
    }
  }

  static Future<int> readAppVersionCode() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  static Future<String> readAppVersion() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kAppVer) ?? '1.0.0';
  }

  static Future<void> saveAppVersion(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAppVer, v);
  }

  static Future<void> clearAuth() async {
    await _secure.delete(key: _kToken);
    await _secure.delete(key: _kRefresh);
  }

  // ============ DEVICE LOCK (client-side) ============
  static const _kLockedUser = 'locked_device_user';

  static Future<String?> getLockedUser() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kLockedUser);
  }

  static Future<void> setLockedUser(String? user) async {
    final p = await SharedPreferences.getInstance();
    if (user == null) {
      await p.remove(_kLockedUser);
    } else {
      await p.setString(_kLockedUser, user);
    }
  }


  // ============ PENDING RESTART ============
  static const _kPendingRestart = 'pending_restart';

  static Future<bool> getPendingRestart() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kPendingRestart) ?? false;
  }

  static Future<void> setPendingRestart(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPendingRestart, value);
  }

}
