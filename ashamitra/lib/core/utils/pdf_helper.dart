import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import '../theme/app_colors.dart';

class PdfHelper {
  static Future<void> saveAndOpen(pw.Document doc, String fileName) async {
    try {
      final bytes = await doc.save();

      // Save to Downloads on Android, Documents on others
      final Directory dir;
      if (Platform.isAndroid) {
        final downloads = Directory('/storage/emulated/0/Download');
        dir = downloads.existsSync() ? downloads : await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final path = '${dir.path}/$fileName';
      await File(path).writeAsBytes(bytes, flush: true);

      // Open with system PDF viewer
      final result = await OpenFile.open(path);

      if (result.type == ResultType.done) {
        Get.snackbar(
          '✅ PDF Downloaded',
          'Saved to Downloads: $fileName',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.safeGreen,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 3),
        );
      } else {
        // File saved but couldn't open — still tell user where it is
        Get.snackbar(
          '✅ PDF Saved',
          'File saved to Downloads/$fileName\n(${result.message})',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.safeGreen,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not save PDF: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.emergencyRed,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }
}
