import 'package:flutter/material.dart';

class OnboardingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const OnboardingCard({super.key, required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(icon, size: 64),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
