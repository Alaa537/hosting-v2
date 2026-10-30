import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/models.dart';
import '../models/app_models.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/glass_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_toast.dart';
import '../utils/error_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;
  ServerResources? _res;
  AppStatus? _app;
  String? _err;
  bool _loading = true;
  bool _fullDialogShown = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final api = context.read<AuthProvider>().api!;
    try {
      final r = await Future.wait([api.serverResources(), api.appStatus()]);
      if (!mounted) return;
      setState(() {
        _res = r[0] as ServerResources;
        _app = r[1] as AppStatus;
        _err = null;
        _loading = false;
      });
      _checkServerFull(r[0] as ServerResources);
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = friendlyError(e); _loading = false; });
    }
  }

  void _checkServerFull(ServerResources r) {
    final cpu = r.cpu ?? 0;
    final mem = r.memPercent ?? 0;
    final disk = r.diskPercent ?? 0;

    final isFull = cpu >= 99 || mem >= 99 || disk >= 99;

    if (isFull && !_fullDialogShown) {
      _fullDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showFullWarning(cpu, mem, disk);
      });
    } else if (!isFull && _fullDialogShown) {
      _fullDialogShown = false;
    }
  }

  void _showFullWarning(double cpu, double mem, double disk) {
    final issues = <String>[];
    if (cpu >= 99) issues.add('🔴 CPU وصل للحد الأقصى: ${cpu.toStringAsFixed(1)}%');
    if (mem >= 99) issues.add('🟠 RAM وصلت للحد الأقصى: ${mem.toStringAsFixed(1)}%');
    if (disk >= 99) issues.add('🟡 Disk وصل للحد الأقصى: ${disk.toStringAsFixed(1)}%');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: C.danger.withValues(alpha: .15),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: C.danger.withValues(alpha: .4), blurRadius: 20)],
          ),
          child: const Icon(Icons.warning_amber_rounded, color: C.danger, size: 36),
        ),
        title: const Text('⚠️ السيرفر وصل للحد الأقصى',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('المعالج أو الذاكرة أو التخزين وصل للحد الأقصى.',
                style: TextStyle(color: C.muted, fontSize: 13, height: 1.6)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: C.danger.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.danger.withValues(alpha: .3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: issues.map((i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(i, style: const TextStyle(color: Colors.white, fontSize: 12)),
                )).toList(),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: C.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('فهمت', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: C.primary,
          backgroundColor: C.surface,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(),
              const SizedBox(height: 16),
              if (_loading) const SkeletonList(count: 4),
              if (_err != null) _errCard(),
              if (_res != null) _resourcesCard(_res!),
              if (_app != null) ...[
                const SizedBox(height: 16),
                _appCard(_app!),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final user = context.watch<AuthProvider>().user;
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
              colors: [C.primary, C.accent]).createShader(r),
          child: const Text('HOSTING',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  letterSpacing: 2, color: Colors.white)),
        ),
        Text('Signed in as ${user?.username ?? '—'}',
            style: const TextStyle(color: C.muted, fontSize: 12)),
      ])),
      if (user?.isAdmin == true)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: C.accent, borderRadius: BorderRadius.circular(20)),
          child: const Text('ADMIN',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 10)),
        ),
    ]);
  }

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

  Widget _resourcesCard(ServerResources r) {
    final stateC = stateColor(r.state);
    return GlassCard(
      accent: stateC,
      glow: r.state == 'running',
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(color: stateColor(r.state), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(r.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Text(r.state.toUpperCase(),
              style: TextStyle(color: stateColor(r.state),
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.timer_outlined, size: 14, color: C.muted),
          const SizedBox(width: 4),
          Text(fTime(r.uptimeSeconds), style: const TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(width: 16),
          const Icon(Icons.favorite_border, size: 14, color: C.muted),
          const SizedBox(width: 4),
          Text(r.healthLevel.toUpperCase(),
              style: TextStyle(color: r.healthLevel == 'ok' ? C.success : C.warning,
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 18),
        _bar('CPU', r.cpu, null, null, C.primary),
        const SizedBox(height: 12),
        _bar('MEM', r.memPercent, r.memUsed, r.memLimit, C.accent),
        const SizedBox(height: 12),
        _bar('DISK', r.diskPercent, r.diskUsed, r.diskLimit, C.info),
        const SizedBox(height: 14),
        Row(children: [
          _net('▼', fSize(r.netRx), C.success),
          const SizedBox(width: 20),
          _net('▲', fSize(r.netTx), C.accent),
        ]),
        if (r.healthIssues.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...r.healthIssues.take(3).map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('⚠ ', style: TextStyle(color: C.warning)),
              Expanded(child: Text(i,
                  style: const TextStyle(color: C.warning, fontSize: 12))),
            ]),
          )),
        ],
      ]),
    );
  }

  Widget _bar(String label, double? pct, int? used, int? limit, Color color) {
    final v = pct ?? 0;
    final effectiveColor = v < 75
        ? C.success
        : v < 90
            ? C.warning
            : C.danger;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        SizedBox(
          width: 42,
          child: Text(label, style: TextStyle(
            color: C.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          )),
        ),
        Expanded(
          child: Stack(
            children: [
              // الخلفية
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: C.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // الشريط
              FractionallySizedBox(
                widthFactor: (v / 100).clamp(0, 1),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      effectiveColor.withValues(alpha: .7),
                      effectiveColor,
                    ]),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: effectiveColor.withValues(alpha: .5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: effectiveColor.withValues(alpha: .3),
            ),
          ),
          child: Text(
            '${v.toStringAsFixed(1)}%',
            style: TextStyle(
              color: effectiveColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ]),
      if (limit != null && limit > 0) Padding(
        padding: const EdgeInsets.only(left: 42, top: 6),
        child: Row(children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: .6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${fSize(used)} / ${fSize(limit)}',
            style: TextStyle(
              color: C.muted.withValues(alpha: .7),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _net(String arrow, String v, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(arrow, style: TextStyle(color: c, fontSize: 14)),
    const SizedBox(width: 4),
    Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  ]);

  Widget _appCard(AppStatus st) {
    final c = stateColor(st.state);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('تطبيقي',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(st.state.toUpperCase(),
                style: TextStyle(color: c, fontSize: 9,
                    fontWeight: FontWeight.w900, letterSpacing: .8)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(st.app.exists ? Icons.check_circle : Icons.cancel,
              color: st.app.exists ? C.success : C.danger, size: 14),
          const SizedBox(width: 6),
          Text('app.py ${st.app.exists ? "موجود" : "غير موجود"}',
              style: TextStyle(color: st.app.exists ? C.success : C.danger,
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(fSize(st.app.size),
              style: const TextStyle(color: C.muted, fontSize: 11,
                  fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.timer_outlined, size: 12, color: C.muted),
          const SizedBox(width: 4),
          Text(fTime(st.uptimeSeconds),
              style: const TextStyle(color: C.muted, fontSize: 11)),
        ]),
      ]),
    );
  }
}
