import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  final _i = TextEditingController();
  bool _busy = false;
  String? _err;
  String? _pending;

  Future<void> _submit() async {
    if (_u.text.trim().length < 3) {
      setState(() => _err = 'Username must be at least 3 characters');
      return;
    }
    if (_p.text.length < 8) {
      setState(() => _err = 'Password must be at least 8 characters');
      return;
    }
    setState(() { _busy = true; _err = null; _pending = null; });
    final e = await context.read<AuthProvider>().register(
        _u.text.trim(), _p.text, _i.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (e != null && e.startsWith('PENDING:')) {
        final parts = e.substring(8).split('|');
        final msg = parts[0];
        final reason = parts.length > 1 ? parts[1] : 'admin_required';
        if (reason == 'ip_rate_limit') {
          _pending = '⚠️ تم رصد محاولات كثيرة من نفس الشبكة.
طلبك في انتظار مراجعة الإدارة.';
        } else if (reason == 'admin_required') {
          _pending = '✅ تم إنشاء طلبك بنجاح.
في انتظار موافقة الإدارة.';
        } else {
          _pending = msg;
        }
      } else if (e != null) {
        _err = e;
      }});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _u, decoration: const InputDecoration(
              labelText: 'Username', prefixIcon: Icon(Icons.person_outline, color: C.primary))),
            const SizedBox(height: 14),
            TextField(controller: _p, obscureText: true,
                decoration: const InputDecoration(
              labelText: 'Password (min 8)', prefixIcon: Icon(Icons.lock_outline, color: C.primary))),
            const SizedBox(height: 14),
            TextField(controller: _i, decoration: const InputDecoration(
              labelText: 'Invite code (optional)',
              prefixIcon: Icon(Icons.vpn_key_outlined, color: C.primary))),
            if (_err != null) ...[
              const SizedBox(height: 14),
              Text(_err!, style: const TextStyle(color: C.danger)),
            ],
            if (_pending != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.warning.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.warning.withValues(alpha: .4)),
                ),
                child: Text(_pending!, style: const TextStyle(color: C.warning)),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('REGISTER'),
            ),
          ]),
        ),
      ),
    );
  }
}
