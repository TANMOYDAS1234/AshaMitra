import 'dart:convert';
import 'package:flutter/material.dart';

/// Patient photo helpers. The photo is stored as a compressed base64 JPEG in
/// `patient.mcpDetails['photo']` and synced with the patient, so it's available
/// anywhere a PatientModel (or its toJson) is in hand.

/// Decodes the base64 photo into an [ImageProvider], or null for empty/invalid
/// data so callers fall back to an initial/icon avatar.
ImageProvider? patientPhotoProvider(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  try {
    return MemoryImage(base64Decode(b64));
  } catch (_) {
    return null;
  }
}

/// Full-screen, pinch-to-zoom viewer — used by "hold (long-press) to view" on
/// any patient avatar. No-op if there's no photo.
void showPatientPhotoDialog(BuildContext context, String? b64, {String? name}) {
  final img = patientPhotoProvider(b64);
  if (img == null) return;
  showDialog(
    context: context,
    barrierColor: Colors.black,
    // Material ancestor gives the content a proper DefaultTextStyle — without
    // it, raw Text in the overlay renders Flutter's yellow debug underline.
    builder: (ctx) => Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(child: Image(image: img, fit: BoxFit.contain)),
              ),
            ),
            if (name != null && name.trim().isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 44,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 40,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 30),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
