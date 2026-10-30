import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/error_utils.dart';
import '../widgets/dialogs.dart';
import '../widgets/section_card.dart';
import '../services/audio_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/skeleton.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});
  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  ServerResources? _r;
  bool _loading = true;
  String? _err;
  bool _noServer = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await context.read<AuthProvider>().api!.serverResources();
      if (!mounted) return;
      setState(() { _r = r; _err = null; _noServer = false; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyError(e);
      setState(() {
        _err = msg;
        _noServer = msg.contains('لا يوجد سيرفر') || msg.contains('404');
        _loading = false;
      });
    }
  }

  Future<void> _power(String sig, {bool danger = false, String? confirmMsg}) async {
    if (danger && !await confirm(context, 'تأكيد', msg: confirmMsg, danger: true)) return;
    if (!mounted) return;
    try {
      final api = context.read<AuthProvider>().api!;
      
      // v5 API uses /app/start, /app/stop, /app/restart, /app/kill
      if (sig == 'start') {
        await api.appStart();
        AudioService.playStart();
      } else if (sig == 'stop') {
        await api.appStop();
        AudioService.playStop();
      } else if (sig == 'restart') {
        await api.appRestart();
        AudioService.playStart();
      } else if (sig == 'kill') {
        await api.appKill();
        AudioService.playStop();
      }
      
      if (mounted) snack(context, 'تم إرسال الأمر: $sig');
      _load();
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  // ✅ FIXED: Auto-restart now properly toggles and updates state
  Future<void> _autoRestart() async {
    final auth = context.read<AuthProvider>();
    try {
      final current = auth.user?.autoRestart ?? false;
      final newValue = !current;

      // أرسل الأمر
      await auth.api!.setAutoRestart(newValue);

      // حدّث بيانات المستخدم من السيرفر
      await auth.refreshMe();

      if (!mounted) return;

      // تحقق أن القيمة تغيرت فعلاً
      final updated = auth.user?.autoRestart ?? newValue;
      if (updated == newValue) {
        snack(context, newValue
            ? '✅ تم تفعيل إعادة التشغيل التلقائي'
            : '⛔ تم إيقاف إعادة التشغيل التلقائي');
      } else {
        snackInfo(context, 'القيمة لم تتغير — أعد المحاولة');
      }
    } catch (e) {
      if (mounted) snack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السيرفر'),
        actions: [
          IconButton(onPressed: _load,
              icon: const Icon(Icons.refresh, color: C.primary)),
        ],
      ),
      body: SafeArea(child: _loading
        ? const SkeletonList(count: 4)
        : RefreshIndicator(
            onRefresh: _load,
            color: C.primary,
            backgroundColor: C.surface,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (_noServer) _noServerCard(),
              if (_err != null && !_noServer) _errCard(),
              if (_r != null) ...[
                _statsCard(_r!),
                const SizedBox(height: 16),

                // Power controls
                SectionCard(
                  title: 'التحكم في الطاقة',
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    _action(Icons.play_arrow, 'تشغيل', C.success,
                        () => _power('start')),
                    _action(Icons.restart_alt, 'إعادة', C.warning,
                        () => _power('restart')),
                    _action(Icons.stop, 'إيقاف', C.info,
                        () => _power('stop')),
                    _action(Icons.power_settings_new, 'Kill', C.danger,
                        () => _power('kill', danger: true,
                            confirmMsg: 'إجبار الإيقاف؟')),
                  ]),
                ),
                const SizedBox(height: 14),

                // Auto-restart with current state
                _autoRestartCard(),
              ],
              const SizedBox(height: 30),
            ]),
          )),
    );
  }

  // ✅ NEW: Dedicated card for auto-restart with visual state
  Widget _autoRestartCard() {
    final auth = context.watch<AuthProvider>();
    final enabled = auth.user?.autoRestart ?? false;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled
              ? C.success.withValues(alpha: .5)
              : C.border,
          width: enabled ? 1.5 : 1,
        ),
        boxShadow: enabled
            ? [BoxShadow(
                color: C.success.withValues(alpha: .15),
                blurRadius: 20, spreadRadius: 2)]
            : [],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: (enabled ? C.success : C.muted).withValues(alpha: .15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            enabled ? Icons.autorenew : Icons.block,
            color: enabled ? C.success : C.muted,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إعادة التشغيل التلقائي',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              enabled ? 'مُفعّل — يعيد التشغيل عند الانهيار'
                     : 'متوقف — لن يُعاد التشغيل تلقائياً',
              style: TextStyle(
                color: enabled ? C.success : C.muted,
                fontSize: 11, fontWeight: FontWeight.w600,
              ),
            ),
          ],
        )),
        Switch(
          value: enabled,
          onChanged: (_) => _autoRestart(),
          activeColor: C.success,
        ),
      ]),
    );
  }

  Widget _noServerCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: C.warning.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.warning.withValues(alpha: .4)),
    ),
    child: Column(children: [
      const Icon(Icons.dns_outlined, color: C.warning, size: 36),
      const SizedBox(height: 10),
      const Text('لا يوجد سيرفر',
          style: TextStyle(color: C.warning, fontSize: 16,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('لم يتم تخصيص سيرفر لحسابك بعد.',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.muted, fontSize: 12)),
    ]),
  );

  Widget _errCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: C.danger.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: C.danger.withValues(alpha: .4)),
    ),
    child: Row(children: [
      const Icon(Icons.wifi_off, color: C.danger, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(_err!,
          style: const TextStyle(color: C.danger, fontSize: 12))),
    ]),
  );

  Widget _statsCard(ServerResources r) {
    final stateC = stateColor(r.state);
    return GlassCard(
      accent: stateC,
      glow: r.state == 'running',
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10,
          decoration: BoxDecoration(color: stateColor(r.state),
              shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(r.name,
            style: const TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700))),
        Text(r.state.toUpperCase(),
            style: TextStyle(color: stateColor(r.state),
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        const Icon(Icons.timer_outlined, size: 14, color: C.muted),
        const SizedBox(width: 4),
        Text(fTime(r.uptimeSeconds),
            style: const TextStyle(color: C.muted, fontSize: 12)),
      ]),
      const SizedBox(height: 18),
      _bar('CPU', r.cpu, null, null),
      const SizedBox(height: 12),
      _bar('MEM', r.memPercent, r.memUsed, r.memLimit),
      const SizedBox(height: 12),
      _bar('DISK', r.diskPercent, r.diskUsed, r.diskLimit),
      const SizedBox(height: 14),
      Row(children: [
        _net('▼', fSize(r.netRx), C.success),
        const SizedBox(width: 20),
        _net('▲', fSize(r.netTx), C.accent),
      ]),
    ]),
    );
  }

  Widget _bar(String label, double? pct, int? used, int? limit) {
    final v = pct ?? 0;
    final c = v < 75 ? C.success : v < 90 ? C.warning : C.danger;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        SizedBox(width: 42, child: Text(label,
            style: const TextStyle(color: C.muted, fontSize: 11,
                fontWeight: FontWeight.w700))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: (v / 100).clamp(0, 1),
            minHeight: 6, backgroundColor: C.border,
            valueColor: AlwaysStoppedAnimation(c)))),
        const SizedBox(width: 10),
        SizedBox(width: 44, child: Text('${v.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700))),
      ]),
      if (limit != null && limit > 0) Padding(
        padding: const EdgeInsets.only(left: 42, top: 3),
        child: Text('${fSize(used)} / ${fSize(limit)}',
            style: const TextStyle(color: C.muted, fontSize: 10)),
      ),
    ]);
  }

  Widget _net(String a, String v, Color c) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(a, style: TextStyle(color: c, fontSize: 14)),
        const SizedBox(width: 4),
        Text(v, style: const TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600)),
      ]);

  Widget _action(IconData ic, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: .18),
                color.withValues(alpha: .08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: .5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .25),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(ic, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: .3,
            )),
          ]),
        ),
      ),
    );
  }
}
