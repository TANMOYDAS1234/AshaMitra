import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../features/auth/data/models/user_model.dart';

/// Renders a circular avatar from Atlas base64 or local file path.
/// Falls back to an initial letter if no photo is set.
class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final double size;
  final Color backgroundColor;
  final Color textColor;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 72,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final photoPath = user?.profileImagePath;
    final name = user?.name ?? '';

    ImageProvider? imageProvider;
    if (photoPath != null) {
      if (user!.isBase64Photo) {
        // Strip the data URI prefix and decode
        final base64Str = photoPath.contains(',')
            ? photoPath.split(',').last
            : photoPath;
        try {
          imageProvider = MemoryImage(base64Decode(base64Str));
        } catch (_) {}
      } else {
        // Legacy local file path
        try {
          imageProvider = FileImage(File(photoPath));
        } catch (_) {}
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: imageProvider != null
            ? Image(image: imageProvider, fit: BoxFit.cover)
            : Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: TextStyle(
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
      ),
    );
  }
}
