import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bootstrap.dart';
import '../utils/constants.dart';
import '../services/audio_service.dart';

class BannerStrip extends StatefulWidget {
  final BannerInfo banner;
  final VoidCallback? onDismiss;
  const BannerStrip({super.key, required this.banner, this.onDismiss});

  @override
  State<BannerStrip> createState() => _BannerStripState();
}

class _BannerStripState extends State<BannerStrip> {
  @override
  void initState() {
    super.initState();
    AudioService.playNotification();
  }

  Color get _color {
    switch (widget.banner.color) {
      case 'warning': return C.warning;
      case 'error': return C.danger;
      case 'success': return C.success;
      case 'info': return C.info;
      default: return C.primary;
    }
  }

  IconData get _icon {
    switch (widget.banner.icon) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'server': return Icons.dns_outlined;
      case 'gift': return Icons.card_giftcard;
      case 'download': return Icons.download_rounded;
      case 'info': return Icons.info_outline;
      default: return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _color.withValues(alpha: .18),
            C.surfaceHi.withValues(alpha: .95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: .6), width: 1.2),
        boxShadow: [
          BoxShadow(color: _color.withValues(alpha: .25), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: _color.withValues(alpha: .35), blurRadius: 10)],
              ),
              child: Icon(_icon, color: _color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.banner.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
            if (widget.banner.actionUrl != null)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 18,
                icon: Icon(Icons.open_in_new, color: _color),
                onPressed: () async {
                  try {
                    await launchUrl(Uri.parse(widget.banner.actionUrl!),
                        mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
            if (widget.onDismiss != null)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 16,
                icon: const Icon(Icons.close, color: C.muted),
                onPressed: widget.onDismiss,
              ),
          ]),
        ),
      ),
    );
  }
}
