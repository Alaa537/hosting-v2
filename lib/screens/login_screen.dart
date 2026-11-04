import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/device_info.dart';
import '../utils/error_utils.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;

  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final username = _user.text.trim();
    final password = _pass.text;
    final e = await context.read<AuthProvider>().login(username, password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (e != null) {
      // ← عرض الرسالة الفعلية من AuthProvider
      String msg = e ?? 'خطأ غير معروف';
      if (msg.contains('device_blocked') || msg.contains('blocked')) {
        msg = '🚫 تم حظر هذا الجهاز من قبل الإدارة.
تواصل مع الدعم لفك الحظر.';
      } else if (msg.contains('device already linked') || msg.contains('linked to another')) {
        msg = '⚠️ هذا الجهاز مسجل بحساب آخر.
لا يمكن استخدام حساب مختلف من نفس الجهاز.';
      } else if (msg.contains('account is locked') || msg.contains('locked to another device')) {
        msg = '🔒 هذا الحساب مربوط بجهاز آخر.
اطلب من الإدارة فك القفل، أو استخدم جهازك الأصلي.';
      } else if (msg.contains('invalid_signature')) {
        msg = '⚠️ التطبيق معدّل.
حمّل النسخة الأصلية من القناة الرسمية.';
      } else if (msg.contains('missing_headers')) {
        msg = '⚠️ التطبيق قديم جداً.
حمّل أحدث نسخة.';
      }
      _showError('فشل تسجيل الدخول', msg);
    }
  }

  void _showError(String title, String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.danger.withValues(alpha: .15),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: C.danger.withValues(alpha: .4),
                blurRadius: 24, spreadRadius: 2),
          ],
        ),
        child: const Icon(Icons.error_outline, color: C.danger, size: 34),
      ),
      title: Text(title, textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      content: Text(msg, textAlign: TextAlign.center,
          style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5)),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسناً'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF05050C),
      body: Stack(children: [
        // Animated blobs
        AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) {
            final t = _bgCtrl.value * 2 * math.pi;
            return Stack(children: [
              _blob(size.width * (.25 + .15 * math.cos(t)),
                  size.height * .25,
                  240,
                  C.primary.withValues(alpha: .30)),
              _blob(size.width * (.75 + .12 * math.sin(t)),
                  size.height * .7,
                  220,
                  C.accent.withValues(alpha: .30)),
            ]);
          },
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),

                  // Logo
                  Center(child: _logoMark())
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(
                          begin: const Offset(.6, .6),
                          curve: Curves.elasticOut,
                          duration: 900.ms),

                  const SizedBox(height: 24),

                  // Title
                  Center(
                    child: ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                          colors: [C.primary, C.accent]).createShader(r),
                      child: const Text('HOST PANEL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Colors.white)),
                    ),
                  ).animate().fadeIn(duration: 700.ms, delay: 300.ms),

                  const SizedBox(height: 4),
                  const Center(
                    child: Text('تسجيل الدخول للمتابعة',
                        style: TextStyle(color: C.muted, fontSize: 12,
                            letterSpacing: 1)),
                  ).animate().fadeIn(duration: 700.ms, delay: 500.ms),

                  const SizedBox(height: 44),

                  // User field
                  _glowField(
                    controller: _user,
                    label: 'اسم المستخدم',
                    icon: Icons.person_outline,
                  ).animate().fadeIn(duration: 500.ms, delay: 700.ms)
                      .slideX(begin: -.15, end: 0),

                  const SizedBox(height: 16),

                  // Pass field
                  _glowField(
                    controller: _pass,
                    label: 'كلمة المرور',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: C.muted, size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    onSubmitted: (_) => _submit(),
                  ).animate().fadeIn(duration: 500.ms, delay: 900.ms)
                      .slideX(begin: -.15, end: 0),

                  const SizedBox(height: 32),

                  // Login button
                  _glowButton(
                    label: _busy ? 'جاري الدخول…' : 'دخول',
                    busy: _busy,
                    onTap: _busy ? null : _submit,
                    icon: Icons.login_rounded,
                  ).animate().fadeIn(duration: 500.ms, delay: 1100.ms)
                      .slideY(begin: .2, end: 0),

                  const SizedBox(height: 14),

                  // Register link
                  TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('ليس لديك حساب؟ أنشئ حساباً',
                        style: TextStyle(color: C.primary,
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ).animate().fadeIn(duration: 500.ms, delay: 1300.ms),

                  const SizedBox(height: 24),

                  // Footer
                  Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.shield_outlined,
                          color: C.success, size: 14),
                      const SizedBox(width: 6),
                      Text('اتصال محمي ومشفّر',
                          style: TextStyle(
                              color: C.muted.withValues(alpha: .8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ).animate().fadeIn(duration: 700.ms, delay: 1500.ms),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _logoMark() {
    return Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [C.primary, C.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: C.primary.withValues(alpha: .55),
              blurRadius: 30, spreadRadius: 4),
          BoxShadow(
              color: C.accent.withValues(alpha: .35),
              blurRadius: 50, spreadRadius: 8),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: Color(0xFF05050C), shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.rocket_launch_rounded,
              color: Colors.white, size: 40),
        ),
      ),
    );
  }

  Widget _blob(double cx, double cy, double r, Color color) {
    return Positioned(
      left: cx - r, top: cy - r,
      child: Container(
        width: r * 2, height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color, color.withValues(alpha: .15), Colors.transparent,
          ], stops: const [0, .5, 1]),
        ),
      ),
    );
  }

  Widget _glowField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            C.surface.withValues(alpha: .9),
            C.surfaceHi.withValues(alpha: .7),
          ],
        ),
        border: Border.all(
          color: C.primary.withValues(alpha: .3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: C.primary.withValues(alpha: .15),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        onFieldSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: C.muted.withValues(alpha: .9)),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                C.primary.withValues(alpha: .2),
                C.primary.withValues(alpha: .05),
              ]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: C.primary, size: 18),
          ),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          filled: false,
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
      ),
    );
  }

  Widget _glowButton({
    required String label,
    required bool busy,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
            colors: [C.primary, C.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight),
        boxShadow: [
          BoxShadow(
              color: C.primary.withValues(alpha: .5),
              blurRadius: 22, spreadRadius: 2),
          BoxShadow(
              color: C.accent.withValues(alpha: .3),
              blurRadius: 32, spreadRadius: 4),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: busy
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.black))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.black, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(label,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1,
                        )),
                  ]),
          ),
        ),
      ),
    );
  }
}
