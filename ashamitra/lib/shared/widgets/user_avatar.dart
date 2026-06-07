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

  // Decode each photo only ONCE and reuse the same ImageProvider instance
  // across rebuilds. Without this, every rebuild created a new MemoryImage
  // (a fresh Uint8List), so Flutter re-decoded the image and the avatar
  // flickered — very visible on the triage screen, which rebuilds many times
  // a second while the mic is open. Keyed by the photo string so it's shared
  // across all avatars and survives parent rebuilds.
  static final Map<String, ImageProvider> _providerCache = {};

  static ImageProvider? _providerFor(UserModel user) {
    final photoPath = user.profileImagePath;
    if (photoPath == null) return null;
    final cached = _providerCache[photoPath];
    if (cached != null) return cached;
    ImageProvider? p;
    if (user.isBase64Photo) {
      final base64Str =
          photoPath.contains(',') ? photoPath.split(',').last : photoPath;
      try {
        p = MemoryImage(base64Decode(base64Str));
      } catch (_) {}
    } else {
      try {
        p = FileImage(File(photoPath));
      } catch (_) {}
    }
    if (p != null) _providerCache[photoPath] = p;
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
    final imageProvider = user == null ? null : _providerFor(user!);

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
