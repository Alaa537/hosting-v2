import 'package:flutter/material.dart';
import '../utils/constants.dart';

class BlockedScreen extends StatelessWidget {
  final String message;
  const BlockedScreen({super.key, required this.message});

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
              const Icon(Icons.block, color: C.danger, size: 80),
              const SizedBox(height: 24),
              const Text('تم حظر التطبيق', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
