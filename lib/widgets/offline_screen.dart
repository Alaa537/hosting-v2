import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});
  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.black.withValues(alpha: .85),
      child: SafeArea(
        child: Stack(children: [
          // Animated blobs in the background
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final t = _pulseCtrl.value;
              return Stack(children: [
                Positioned(
                  left: -size.width * .2 + 40 * t,
                  top: -size.height * .1 - 20 * t,
                  child: _blob(320, C.danger.withValues(alpha: .15)),
                ),
                Positioned(
                  right: -size.width * .25 - 30 * t,
                  bottom: -size.height * .2 + 30 * t,
                  child: _blob(300, C.warning.withValues(alpha: .10)),
                ),
              ]);
            },
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glowing wifi-off icon
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) {
                      final s = 1.0 + (_pulseCtrl.value * .06);
                      return Transform.scale(
                        scale: s,
                        child: Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              C.danger.withValues(alpha: .25),
                              C.danger.withValues(alpha: .05),
                            ]),
                            border: Border.all(
                              color: C.danger.withValues(alpha: .5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: C.danger.withValues(alpha: .4 + .2 * _pulseCtrl.value),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            color: C.danger,
                            size: 64,
                          ),
                        ),
                      );
                    },
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(.7, .7), curve: Curves.elasticOut),

                  const SizedBox(height: 32),

                  ShaderMask(
                    shaderCallback: (r) => LinearGradient(colors: [
                      C.danger,
                      C.warning,
                    ]).createShader(r),
                    child: const Text(
                      'انقطع الاتصال بالإنترنت',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: .5,
                      ),
                    ),
                  ).animate().fadeIn(duration: 700.ms, delay: 200.ms),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: C.surface.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: C.danger.withValues(alpha: .3),
                      ),
                    ),
                    child: const Text(
                      'يرجى التحقق من اتصالك بالإنترنت.\n'
                      'سيتم استئناف العمل تلقائياً عند عودة الاتصال.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.7,
                      ),
                    ),
                  ).animate().fadeIn(duration: 700.ms, delay: 400.ms),

                  const SizedBox(height: 28),

                  // Reconnect indicator (auto)
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                C.primary.withValues(alpha: .6 + .4 * _pulseCtrl.value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'في انتظار الاتصال…',
                            style: TextStyle(
                              color: C.muted.withValues(alpha: .7 + .3 * _pulseCtrl.value),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ).animate().fadeIn(duration: 900.ms, delay: 800.ms),

                  const SizedBox(height: 40),

                  // Telegram support button
                  GestureDetector(
                    onTap: () async {
                      // Cannot open URL if offline, but keep for consistency
                      // No-op if no internet
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: C.surface.withValues(alpha: .6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, color: C.muted, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'تأكد من تشغيل Wi-Fi أو بيانات الجوال',
                            style: TextStyle(
                              color: C.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 900.ms, delay: 1000.ms),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: .0)],
          stops: const [0, 1],
        ),
      ),
    );
  }
}
