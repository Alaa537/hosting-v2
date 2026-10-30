import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../widgets/dialogs.dart';
import '../widgets/glass_card.dart';
import 'profile_screen.dart';
import 'ai_assistant_screen.dart';
import 'backups_screen.dart';
import 'notifications_screen.dart';
import 'sessions_screen.dart';
import 'user_info_screen.dart';
import 'app_screen.dart';
import 'live_console_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';
import 'developer_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  C.primary.withValues(alpha: .15),
                  C.accent.withValues(alpha: .15),
                ]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: C.primary.withValues(alpha: .3)),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: C.primary.withValues(alpha: .2),
                  child: Text(
                    (user?.username ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: C.primary,
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.username ?? '—',
                        style: const TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: user?.isAdmin == true ? C.accent : C.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (user?.role ?? 'user').toUpperCase(),
                          style: const TextStyle(color: Colors.black,
                              fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (user != null && user.unreadNotifications > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.circle, size: 8, color: C.accent),
                        const SizedBox(width: 4),
                        Text('${user.unreadNotifications}',
                            style: const TextStyle(color: C.accent,
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ]),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 20),
            _tile(context, Icons.auto_awesome, 'المساعد الذكي',
                'Gemini AI · اسألني أي شيء',
                () => _push(context, const AIAssistantScreen()), accent: true),
            _tile(context, Icons.code, 'معلومات المطور',
                'تعرف على المطور والتواصل',
                () => _push(context, const DeveloperScreen()), accent: true),
            _tile(context, Icons.person_outline, 'الملف الشخصي',
                'معلومات الحساب',
                () => _push(context, const ProfileScreen())),
            _tile(context, Icons.pie_chart_outline, 'معلوماتي',
                'الاستخدام · النشاط · التنبيهات',
                () => _push(context, const UserInfoScreen())),
            _tile(context, Icons.devices_other, 'جلساتي',
                'الأجهزة المسجلة',
                () => _push(context, const SessionsScreen())),
            _tile(context, Icons.rocket_launch_outlined, 'بوتي',
                'بوتي · التحكم',
                () => _push(context, const AppScreen())),
            _tile(context, Icons.terminal, 'وحدة التحكم',
                'السجل المباشر',
                () => _push(context, const LiveConsoleScreen())),
            _tile(context, Icons.backup_outlined, 'النسخ الاحتياطي',
                'إنشاء / استرجاع',
                () => _push(context, const BackupsScreen())),
            _tile(context, Icons.notifications_outlined, 'الإشعارات',
                'الوارد',
                () => _push(context, const NotificationsScreen())),
            if (user?.isAdmin == true)
              _tile(context, Icons.admin_panel_settings_outlined,
                  'لوحة الأدمن', 'المستخدمين · الأجهزة · المحتوى',
                  () => _push(context, const AdminScreen()), accent: true),
            _tile(context, Icons.code, 'معلومات المطور',
                'تعرف على المطور والتواصل',
                () => _push(context, const DeveloperScreen()), accent: true),
            _tile(context, Icons.settings_outlined, 'الإعدادات',
                'كلمة المرور · الجلسات',
                () => _push(context, const SettingsScreen())),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout, color: C.danger),
                title: const Text('تسجيل الخروج',
                    style: TextStyle(color: C.danger,
                        fontWeight: FontWeight.w700)),
                onTap: () async {
                  if (await confirm(context, 'تسجيل الخروج؟',
                      msg: 'سيتم إنهاء الجلسة الحالية.', danger: true)) {
                    if (context.mounted) await auth.logout();
                  }
                },
              ),
            ),
            const SizedBox(height: 30),
            Center(child: Column(children: [
              Text('HOST PANEL',
                  style: TextStyle(color: C.muted.withValues(alpha: .5),
                      fontSize: 12, fontWeight: FontWeight.w900,
                      letterSpacing: 4)),
              const SizedBox(height: 4),
              Text('v1.0.0',
                  style: TextStyle(color: C.muted.withValues(alpha: .5),
                      fontSize: 10)),
            ])),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, IconData ic, String title, String sub,
      VoidCallback onTap, {bool accent = false}) {
    final color = accent ? C.accent : C.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: C.surface.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent
              ? color.withValues(alpha: .4)
              : C.border,
          width: accent ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          if (accent)
            BoxShadow(
              color: color.withValues(alpha: .2),
              blurRadius: 20,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: .1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: .2),
                        color.withValues(alpha: .08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: .3),
                    ),
                  ),
                  child: Icon(ic, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: accent ? C.accent : Colors.white,
                      )),
                      const SizedBox(height: 2),
                      Text(sub, style: TextStyle(
                        color: C.muted.withValues(alpha: .8),
                        fontSize: 11,
                      )),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: color.withValues(alpha: .6), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _push(BuildContext c, Widget w) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => w));
}
