import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('Developer'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _hero(),
            const SizedBox(height: 28),
            _devCard(
              name: 'Alaa Rafeek',
              role: 'Founder · Lead Developer',
              description: 'Expert in app development, reverse engineering, and multiple technologies.',
              skills: const ['Flutter', 'Reverse Engineering', 'Python', 'PHP', 'Java', 'Kotlin'],
              telegram: 'AR_Bou',
              initial: 'A',
              accent: C.primary,
              delay: 100,
            ),

            const SizedBox(height: 32),
            _footer(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [C.primary.withValues(alpha: .2), C.accent.withValues(alpha: .2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.primary.withValues(alpha: .4)),
        boxShadow: [
          BoxShadow(color: C.primary.withValues(alpha: .25), blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: Column(children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [C.primary, C.accent]).createShader(r),
          child: const Text('HOST PANEL',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white)),
        ),
        const SizedBox(height: 8),
        const Text('Built with passion by Alaa Rafeek',
            style: TextStyle(color: C.muted, fontSize: 12.5, letterSpacing: .5)),
      ]),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: .2, end: 0);
  }

  Widget _devCard({
    required String name,
    required String role,
    required String description,
    required List<String> skills,
    required String telegram,
    required String initial,
    required Color accent,
    required int delay,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .35), width: 1.2),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: .2), blurRadius: 24, spreadRadius: 1)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent.withValues(alpha: .2), accent.withValues(alpha: .05)]),
            ),
            child: Row(children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [accent, C.accent]),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: .5), blurRadius: 16)],
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(role, style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .5)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(description, style: const TextStyle(color: C.muted, fontSize: 13, height: 1.6)),
              const SizedBox(height: 16),
              Wrap(spacing: 6, runSpacing: 6, children: skills.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: .3)),
                ),
                child: Text(s, style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w700)),
              )).toList()),
              const SizedBox(height: 18),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final url = Uri.parse('https://t.me/$telegram');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF29B6F6), Color(0xFF0288D1)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF29B6F6).withValues(alpha: .35), blurRadius: 12)],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.telegram, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('@$telegram', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: delay.ms).slideX(begin: .1, end: 0);
  }

  Widget _footer() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.surface.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.favorite, color: C.accent, size: 14),
          const SizedBox(width: 8),
          Text('Crafted with precision and care',
              style: TextStyle(color: C.muted.withValues(alpha: .8), fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 16),
      Text('HOST PANEL © ${DateTime.now().year}\nAll rights reserved',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.muted.withValues(alpha: .5), fontSize: 11, height: 1.5)),
    ]);
  }
}
