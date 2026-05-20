import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'local_storage_service.dart';

class LanguageController extends GetxController {
  static const _key = 'selected_language';

  final selectedIndex = 0.obs;

  static const locales = [
    Locale('bn', 'BD'),
    Locale('hi', 'IN'),
    Locale('en', 'US'),
  ];

  static const labels = ['বাংলা (Bengali)', 'हिन्दी (Hindi)', 'English'];
  static const displayNames = ['বাংলা', 'हिन्दी', 'English'];

  @override
  void onInit() {
    super.onInit();
    final saved = LocalStorageService.get(_key);
    if (saved != null) {
      selectedIndex.value = int.tryParse(saved) ?? 0;
    }
    // Apply saved locale on startup
    Get.updateLocale(locales[selectedIndex.value]);
  }

  Future<void> setLanguage(int index) async {
    selectedIndex.value = index;
    await LocalStorageService.set(_key, index.toString());
    // Get.updateLocale updates the locale inside GetMaterialApp without
    // rebuilding the entire widget tree or resetting the navigator stack
    Get.updateLocale(locales[index]);
  }

  String get currentLabel => labels[selectedIndex.value];
  String get currentDisplayName => displayNames[selectedIndex.value];
}
