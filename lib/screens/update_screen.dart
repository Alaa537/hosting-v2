import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String? url;
  final String? message;
  const ForceUpdateScreen({super.key, this.url, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, color: C.primary, size: 80),
              const SizedBox(height: 24),
              const Text('تحديث إجباري', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Text(message ?? 'يجب تحديث التطبيق للاستمرار.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 16)),
              const SizedBox(height: 32),
              if (url != null)
                ElevatedButton(
                  onPressed: () async {
                    final uri = Uri.parse(url!);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: const Text('تحديث الآن'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
