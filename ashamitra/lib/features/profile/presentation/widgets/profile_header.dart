import 'package:flutter/material.dart';
import '../../../../features/auth/data/models/user_model.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel user;
  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
      const SizedBox(height: 12),
      Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      Text(user.phone, style: const TextStyle(color: Colors.grey)),
      Text(user.role.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1)),
    ]);
  }
}
